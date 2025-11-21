import ipaddress

def generate_flows(filename="flowtables.conf"):
    base_ip = ipaddress.IPv4Address("192.168.112.1")
    src_ip = "10.7.0.0"
    port_src = 443
    port_dst_start = 50176
    protocol = "udp"
    #cpus = [3,4,5,6,7,8,9]
    cpus = [2]
    num_addresses = 4000

    with open(filename, "w") as f:
        for i in range(num_addresses):
            dst_ip = str(base_ip + i)
            port_dst = port_dst_start + i
            flow_id = i  # flow-id increases
            cpu = cpus[i % len(cpus)]
            line = (f"flowtable_ip4 add src {src_ip} dst {dst_ip} "
            f"port_src {port_src} port_dst {port_dst} "
            f"protocol {protocol} flow-id {flow_id} cpu {cpu}\n")
            f.write(line)

if __name__ == "__main__":
    generate_flows()
