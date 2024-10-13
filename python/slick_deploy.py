import boto3
import botocore
import config
import paramiko
import time
import requests
import threading

client = boto3.client('ec2')
ec2 = boto3.resource('ec2')

def deploy_on_ec2(ec2_ip):
    remote_script_path = f"/home/{config.default_linux_user}/prepare_http_server.sh"
    try:
        ssh_client = paramiko.SSHClient()
        ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        ssh_client.connect(ec2_ip, username=config.default_linux_user, key_filename=config.local_ssh_key, timeout=60)
        print(f"Connected to {ec2_ip}")

        sftp = ssh_client.open_sftp()
        sftp.put("prepare_http_server.sh", remote_script_path)
        sftp.close()
        print(f"Uploaded script to {remote_script_path} on {ec2_ip}")

        stdin, stdout, stderr = ssh_client.exec_command(f"chmod +x {remote_script_path}")
        _ = stdout.channel.recv_exit_status()  # Wait for command to complete

        stdin, stdout, stderr = ssh_client.exec_command(f"sudo {remote_script_path} yes")
        exit_status = stdout.channel.recv_exit_status()  # Wait for command to complete

        if exit_status == 0:
            print(f"Script executed successfully on {ec2_ip}")
        else:
            print(f"Error executing script: {stderr.read().decode()}")
        ssh_client.close()

        return wait_for_http_response(f"http://{ec2_ip}")

    except Exception as e:
        print(f"SSH connection to {ec2_ip} failed: {e}")


def wait_for_http_response(url, timeout=120):
    start_time = time.time()
    print(f"Waiting for 200 HTTP response from {url}...")
    while True:
        try:
            response = requests.get(url)
            if response.status_code == 200:
                print(f"Received 200 HTTP response from {url}")
                return True
        except requests.ConnectionError:
            pass

        elapsed_time = time.time() - start_time
        if elapsed_time > timeout:
            print(f"Timed out waiting for 200 HTTP response from {url}")
            return False
        time.sleep(5)

def create_subnet(vpc_id, cidr_block):
    r = client.describe_subnets()
    for subnet in r['Subnets']:
        if subnet['VpcId'] == vpc_id and subnet['CidrBlock'] == cidr_block:
            return subnet['SubnetId']

    r = client.create_subnet(
        CidrBlock=config.default_subnet_cidr,
        VpcId=vpc_id,
    )

    return r['SubnetId']

def create_security_group(vpc_id, sg_name):
    r = client.describe_security_groups()
    for sg in r['SecurityGroups']:
        if sg['VpcId'] == vpc_id and sg['GroupName'] == sg_name:
            return sg['GroupId']

    r = client.create_security_group(
        Description='For ssh and http inbound',
        GroupName='default-docker',
        VpcId=vpc_id,
    )

    new_group_id = r['GroupId']
    client.authorize_security_group_egress(
        GroupId=new_group_id,
        IpPermissions=[
            {
                'IpProtocol': 'tcp',
                'FromPort': 22,
                'ToPort': 22,
                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
            },
            {
                'IpProtocol': 'tcp',
                'FromPort': 80,
                'ToPort': 80,
                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
            }
        ]
    )
    client.authorize_security_group_ingress(
        GroupId=new_group_id,
        IpPermissions=[
            {
                'IpProtocol': "-1",
                'FromPort': -1,
                'ToPort': -1,
                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
            },
        ]
    )
    return new_group_id

def create_instance(sb_id, sg_id):
    created_instances = {}
    r = client.run_instances(
        BlockDeviceMappings=[
            {
                'DeviceName': '/dev/sdh',
                'Ebs': {
                    'VolumeSize': 8,
                },
            },
        ],
        ImageId=config.us_east_1_ami,
        InstanceType=config.instance_type,
        KeyName=config.uploaded_key_pair_name,
        MaxCount=config.needed_ec2_count,
        MinCount=config.needed_ec2_count,
        NetworkInterfaces=[
            {
                'AssociatePublicIpAddress': True,
                'DeleteOnTermination': True,
                "DeviceIndex": 0,
                "SubnetId": sb_id,
            },
        ],
        TagSpecifications=[
            {
                'ResourceType': 'instance',
                'Tags': [
                    {
                        'Key': 'Purpose',
                        'Value': 'test',
                    },
                ],
            },
        ],
    )
    for instance_info in r['Instances']:
        instance_id = instance_info['InstanceId']
        instance = ec2.Instance(instance_id)
        instance.wait_until_running()
        instance.modify_attribute(Groups=[sg_id,])
        instance_public_ip = instance.public_ip_address
        created_instances.update({instance_id: instance_public_ip})
        print(f"Instance {instance_id} with IP {instance_public_ip} has been created")
    with open("my_little_state.txt", "w") as f:
        for instance_id in created_instances:
            f.write(instance_id + "\n")
    return created_instances

def destroy_previous_instances():
    with open("my_little_state.txt", "r") as f:
        for line in f.readlines():
            instance_id = line.strip()
            try:
                instance = ec2.Instance(instance_id)
                instance.terminate()
                print(f"Terminated instance {instance_id}")
            except botocore.exceptions.ClientError:
                print(f"Instance {instance_id} already terminated")

def main():
    destroy_previous_instances()  # for debug
    subnet_id = create_subnet(config.us_east_1_default_vpc_id, config.default_subnet_cidr)
    security_group_id = create_security_group(config.us_east_1_default_vpc_id, config.needed_sg_name)
    new_instances = create_instance(subnet_id, security_group_id)
    time.sleep(10)
    threads = []
    for instance_ip in new_instances.values():
        thread = threading.Thread(
            target=deploy_on_ec2,
            args=(instance_ip,)
        )
        threads.append(thread)
        thread.start()

    for thread in threads:
        thread.join()

if __name__ == '__main__':
    main()