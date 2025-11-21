import ipaddress

def generate_flows(filename="allowlist.conf"):
    base_ip = ipaddress.IPv4Address("192.168.112.1")
    src_ip = "10.7.0.0"
    port_src = 443
    port_dst_start = 50176
    protocol = 17
    num_addresses = 4000

    with open(filename, "w") as f:
        for i in range(num_addresses):
            dst_ip = str(base_ip + i)
            port_dst = port_dst_start + i
            flow_id = i  # flow-id increases
            line = (f"allowlist rule add match hash ipv4_5tuple {src_ip} {dst_ip} {port_src} {port_dst} 17\n")
            f.write(line)

if __name__ == "__main__":
    generate_flows()
