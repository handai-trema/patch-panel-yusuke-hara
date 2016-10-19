# Software patch-panel.
class PatchPanel < Trema::Controller
  def start(_args)
    @patch = Hash.new { [] }
    @mirror = Hash.new{[]}
    logger.info 'PatchPanel started.'
  end

  def switch_ready(dpid)
    @patch[dpid].each do |port_a, port_b|
      delete_flow_entries dpid, port_a, port_b
      add_flow_entries dpid, port_a, port_b
    end
  end

  def create_patch(dpid, port_a, port_b)
    add_flow_entries dpid, port_a, port_b
    @patch[dpid] += [port_a, port_b].sort
  end

  def mirroring(dpid, port_a, port_b)
    
    add_mirroring_entries dpid, port_a, port_b
    @patch[dpid].each do |port_c, port_d|
      if port_c == port_a then
        add_mirroring_entries dpid, port_d, port_b
      elsif port_d == port_a then
        add_mirroring_entries dpid, port_c, port_b
      end
  end
       
         
  def delete_patch(dpid, port_a, port_b)
    delete_flow_entries dpid, port_a, port_b
    @patch[dpid] -= [port_a, port_b].sort
  end

  private

  def add_flow_entries(dpid, port_a, port_b)
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: SendOutPort.new(port_b))
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_b),
                      actions: SendOutPort.new(port_a))
  end

  def add_mirroring_entries(dpid,port_in,port_out)
     send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_in),
                      actions: SendOutPort.new(port_out))
  end
 

  def delete_flow_entries(dpid, port_a, port_b)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_a))
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_b))
  end
end
