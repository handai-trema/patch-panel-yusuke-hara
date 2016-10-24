# Software patch-panel.
class PatchPanel < Trema::Controller
  def start(_args)
    @patch = Hash.new {|hash,key| hash[key] = []  }
    @mirror = Hash.new {|hash,key| hash[key] = []  }
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
    @patch[dpid] << [port_a, port_b].sort
  end

  def mirror(dpid, port, mirror_port)
    @mirror[dpid] << [port,mirror_port]
    patch_port =nil
    @patch[dpid].each do |port_c, port_d|
      if port_c == port then
        patch_port = port_d
      elsif port_d == port then
        patch_port = port_c
      end
    end
    add_mirror dpid,port,patch_port,mirror_port
  end


  def delete_patch(dpid, port_a, port_b)
    return "No such patch\n" if @patch[dpid].delete([port_a, port_b].sort).nil?
    delete_flow_entries dpid, port_a, port_b
    return ""
  end

  def delete_mirror(dpid, port, mirror)
    return "No such mirror\n" if @mirror[dpid].delete([port, mirror]).nil?
    patch_port =nil
    @patch[dpid].each do |port_c, port_d|
      if port_c == port then
        patch_port = port_d
      elsif port_d == port then
        patch_port = port_c
      end
    end
    delete_mirror_flow_entry dpid,port,patch_port
    return ""
  end

  def show_ports(dpid)
    str = ""
    str += ":patch\n"
    @patch[dpid].each do |port_c, port_d|
      str += "#{port_c}:#{port_d}\n"
    end
    str += ":mirror\n"
    @mirror[dpid].each do |port_c, port_d|
      str += "#{port_c} -> #{port_d}\n"
    end
    return str
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


  def delete_flow_entries(dpid, port_a, port_b)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_a))
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_b))
  end



  def add_mirror(dpid, port, patch_port, mirror)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port))
    send_flow_mod_delete(dpid, match: Match.new(in_port: patch_port)) if ! patch_port.nil?
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port),
                      actions: [SendOutPort.new(patch_port), SendOutPort.new(mirror),])
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: patch_port),
                      actions: [SendOutPort.new(port), SendOutPort.new(mirror),]) if ! patch_port.nil?
  end

  def delete_mirror_flow_entry(dpid, port, patch_port)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port))
    send_flow_mod_delete(dpid, match: Match.new(in_port: patch_port)) if ! patch_port.nil?
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port),
                      actions: SendOutPort.new(patch_port))
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: patch_port),
                      actions: SendOutPort.new(port)) if ! patch_port.nil?
  end

end
