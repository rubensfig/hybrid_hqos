import ipaddress

def generate_flows(filename="fdir.conf"):
    base_ip = ipaddress.IPv4Address("192.168.0.1")
    src_ip = "10.0.0.0"
    port_src = 443
    port_dst_start = 50176
    protocol = 17
    num_addresses = 4000

    with open(filename, "w") as f:
        for i in range(num_addresses):
            dst_ip = str(base_ip + i)
            port_dst = port_dst_start + i
            flow_id = i  # flow-id increases
            line = (f"test flow add index {i} src-ip {src_ip} dst-ip {dst_ip} redirect-to-queue 0\n")
            f.write(line)
            line = (f"test flow enable index {i} if0\n")
            f.write(line)

if __name__ == "__main__":
    generate_flows()
