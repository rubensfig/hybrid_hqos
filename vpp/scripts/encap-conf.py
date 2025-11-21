import ipaddress

# st qinq encap flow <id> smac <mac> dmac <mac> svlan <id> cvlan <id>
def generate_flows(filename="encap.conf"):
    base_ip = ipaddress.IPv4Address("192.168.112.1")
    base_smac = "00:11:22:33:44:07"   # fixed value for all flows
    base_dmac = "6e:00:00:00:00:00"
    base_svlan = 0
    base_cvlan = 0
    num_addresses = 4000

    def inc_mac(base_mac: str, offset: int) -> str:
        """Increment MAC address by offset (no dependencies)."""
        mac_int = int(base_mac.replace(":", ""), 16)
        mac_int += offset
        mac_hex = f"{mac_int:012x}"
        return ":".join(mac_hex[i:i+2] for i in range(0, 12, 2))

    with open(filename, "w") as f:
        for flow_id in range(num_addresses):
            smac = base_smac
            dmac = inc_mac(base_dmac, flow_id)
            svlan = base_svlan
            cvlan = base_cvlan + flow_id
            line = (f"set qinq encap flow {flow_id} smac {smac} " 
                    f"dmac {dmac} svlan {svlan} cvlan {cvlan}\n")
            f.write(line)
    
if __name__ == "__main__":
    generate_flows()
