import uvm_pkg::*;
	`include "uvm_macros.svh"

class fifo_config extends uvm_object;
  `uvm_object_utils(fifo_config)
  
  virtual fifo_if vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  int count;
  static int wr_trans = 0;
  static int mon_trans = 0;
  
  function new(string name = "fifo_config");
    super.new(name);
  endfunction
endclass

class fifo_trans extends uvm_sequence_item;
  rand bit rst;
  rand bit wr_en;
  rand bit rd_en;
  rand bit [7:0] data_in;

  bit [7:0] data_out;
  bit full;
  bit empty;

  `uvm_object_utils_begin(fifo_trans)
    `uvm_field_int(wr_en, UVM_ALL_ON)
    `uvm_field_int(rd_en, UVM_ALL_ON)
    `uvm_field_int(data_in, UVM_ALL_ON)
    `uvm_field_int(data_out, UVM_ALL_ON)
    `uvm_field_int(full, UVM_ALL_ON)
    `uvm_field_int(empty, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "fifo_trans");
    super.new(name);
  endfunction
  
  constraint c1{data_in inside {[0:255]};}

endclass

class fifo_base_seq extends uvm_sequence#(fifo_trans);
  `uvm_object_utils(fifo_base_seq)
  
  fifo_config cfg;
  function new(string name = "fifo_base_seq");
    super.new(name);
  endfunction
  task body();
    if(!uvm_config_db#(fifo_config)::get(null,get_full_name(),"fifo_config",cfg))
      `uvm_fatal("IN_BASE_SEQ","get_failed_in_base_seq,check once");
  endtask
endclass

class fifo_reset_seq extends fifo_base_seq;
  `uvm_object_utils(fifo_reset_seq)
  
  function new(string name = "fifo_reset_seq");
    super.new(name);
  endfunction
  
  task body();
    super.body();
    req = fifo_trans::type_id::create("req");
    start_item(req);
    assert(req.randomize() with {rst == 1;});
    finish_item(req);
    req = fifo_trans::type_id::create("req");

  start_item(req);

  assert(req.randomize() with {
    rst   == 0;
    wr_en == 0;
    rd_en == 0;
  });

  finish_item(req);

  endtask
endclass

class fifo_write_seq extends fifo_base_seq;
  `uvm_object_utils(fifo_write_seq)
  
  function new(string name = "fifo_write_seq");
    super.new(name);
  endfunction
  
  task body();
    super.body();
    repeat(cfg.count)begin
      req = fifo_trans::type_id::create("req");
      start_item(req);
      assert(req.randomize() with {rst == 0;wr_en == 1;rd_en == 0;});
      finish_item(req);
    end
  endtask
endclass

class fifo_read_seq extends fifo_base_seq;
  `uvm_object_utils(fifo_read_seq)
  
  function new(string name = "fifo_read_seq");
    super.new(name);
  endfunction
  
  task body();
    super.body();
    repeat(cfg.count)begin
      req = fifo_trans::type_id::create("req");
      start_item(req);
      assert(req.randomize() with {rst == 0;wr_en == 0;rd_en == 1;});
      finish_item(req);
    end
  endtask
endclass

class fifo_wr_rd_seq extends fifo_base_seq;
  `uvm_object_utils(fifo_wr_rd_seq)
  
  function new(string name = "fifo_wr_rd_seq");
    super.new(name);
  endfunction
  
  task body();
    super.body();
    repeat(cfg.count)begin
      req = fifo_trans::type_id::create("req");
      start_item(req);
      assert(req.randomize() with {rst == 0;wr_en == 1;rd_en == 1;});
      finish_item(req);
    end
     req = fifo_trans::type_id::create("req");
  start_item(req);
  assert(req.randomize() with {
    rst == 0;
    wr_en == 0;
    rd_en == 1;
  });
  finish_item(req);
  endtask
endclass

class fifo_sequencer extends uvm_sequencer#(fifo_trans);
  `uvm_component_utils(fifo_sequencer)
  
  function new(string name = "fifo_sequencer",
               uvm_component parent);
    super.new(name,parent);
  endfunction
  
endclass

class fifo_driver extends uvm_driver#(fifo_trans);
  `uvm_component_utils(fifo_driver)
  
  fifo_config cfg;
  virtual fifo_if.DRV_MP vif;
  
  function new(string name = "fifo_driver",
               uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(fifo_config)::get(this,"","fifo_config",cfg))
      `uvm_fatal("IN_DRV","get failed in drv,check once");
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vif = cfg.vif;
  endfunction
  
  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      send_to_dut(req);
      seq_item_port.item_done();
    end
  endtask
  
  task send_to_dut(fifo_trans tx);
    @(vif.drv_cb);
    vif.drv_cb.rst 	    <= tx.rst;
    vif.drv_cb.wr_en	<= tx.wr_en;
    vif.drv_cb.rd_en 	<= tx.rd_en;
    vif.drv_cb.data_in  <= tx.data_in;
    $display("-------------------------------");
    `uvm_info("FIFO_DRIVER",$sformatf("Driver drives the data = %0d",tx.data_in),UVM_LOW)
  
    cfg.wr_trans++;
  endtask
  
  function void extract_phase(uvm_phase phase);
    super.extract_phase(phase);
    `uvm_info(get_type_name(),$sformatf("Total Driver's side transactions = %0d",cfg.wr_trans),UVM_LOW)
  endfunction
endclass
      
class fifo_monitor extends uvm_monitor;
  `uvm_component_utils(fifo_monitor)

  virtual fifo_if.MON_MP vif;
  fifo_config cfg;

  uvm_analysis_port #(fifo_trans) mon_ap;

  function new(string name = "fifo_monitor",
               uvm_component parent);
    super.new(name, parent);
    mon_ap = new("mon_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(fifo_config)::get(this, "", "fifo_config", cfg))
      `uvm_fatal("IN_MON", "Config get failed in monitor")
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      wait(vif.mon_cb.rst === 1'b0);
      collect_dut();
    end
  endtask

  task collect_dut();
    fifo_trans tx;

    tx = fifo_trans::type_id::create("tx");

    @(vif.mon_cb);

    tx.rst      = vif.mon_cb.rst;
    tx.wr_en    = vif.mon_cb.wr_en;
    tx.rd_en    = vif.mon_cb.rd_en;
    tx.data_in  = vif.mon_cb.data_in;
    tx.data_out = vif.mon_cb.data_out;
    tx.full     = vif.mon_cb.full;
    tx.empty    = vif.mon_cb.empty;

    `uvm_info("FIFO_MONITOR",
      $sformatf("rst=%0b wr_en=%0b rd_en=%0b data_in=%0d data_out=%0d full=%0b empty=%0b",
      tx.rst, tx.wr_en, tx.rd_en, tx.data_in,
      tx.data_out, tx.full, tx.empty), UVM_MEDIUM)
    $display("------------------------------");

    mon_ap.write(tx);

    cfg.mon_trans++;

  endtask
  
 function void extract_phase(uvm_phase phase);
    super.extract_phase(phase);
   `uvm_info(get_type_name(),$sformatf("Total Monitor's side transactions = %0d",cfg.mon_trans),UVM_LOW)
  endfunction

endclass

class fifo_agent extends uvm_agent;
  `uvm_component_utils(fifo_agent)
  
  fifo_driver drvh;
  fifo_sequencer seqrh;
  fifo_monitor monh;
  fifo_config cfg;
  
  function new(string name = "fifo_agent",
               uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db#(fifo_config)::get(this,"","fifo_config",cfg))
      `uvm_fatal("IN_AGT"," get failed check once");
    
    monh = fifo_monitor::type_id::create("monh",this);
    
    if(cfg.is_active == UVM_ACTIVE)begin
      drvh = fifo_driver::type_id::create("drvh",this);
      seqrh = fifo_sequencer::type_id::create("seqrh",this);
    end
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(cfg.is_active == UVM_ACTIVE)begin
      drvh.seq_item_port.connect(seqrh.seq_item_export);
    end
  endfunction
endclass

class fifo_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fifo_scoreboard)

  fifo_config cfg;
  uvm_tlm_analysis_fifo #(fifo_trans) fifoh;

  bit [7:0] exp_q[$]; // here just using queue because it models the fifo behavior instead of manually modelling the pointers


  function new(string name = "fifo_scoreboard",
               uvm_component parent);
    super.new(name,parent);
    fifoh = new("fifoh",this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(fifo_config)::get(this, "", "fifo_config", cfg))
      `uvm_fatal("IN_SB", "Config get failed in scoreboard")

  endfunction

  task run_phase(uvm_phase phase);
    fifo_trans tx;

    forever begin
      fifoh.get(tx);
      compare_fifo(tx);
    end
  endtask

  task compare_fifo(fifo_trans tx);

    bit exp_full;
    bit exp_empty;
    bit [7:0] exp_data;

    if (tx.rst) begin
      exp_q.delete(); // fifo will be zero here
    end
       
    else begin

      exp_empty = (exp_q.size() == 0); // just assigning empty and full here
      exp_full  = (exp_q.size() == cfg.count);

      if (tx.wr_en && !exp_full) begin // dut mimic
        exp_q.push_back(tx.data_in);

        `uvm_info("FIFO_SB",
          $sformatf("WRITE SUCCESS: Data=%0d", tx.data_in),
          UVM_MEDIUM)
      end

      if (tx.rd_en && !exp_empty) begin // dut behaviour mimic here
        exp_data = exp_q.pop_front();

        if (tx.data_out !== exp_data) // actual vs expected here
          `uvm_error("FIFO_SB",
            $sformatf("READ FAILED: Expected=%0d Actual=%0d",
                      exp_data, tx.data_out))
        else
          `uvm_info("FIFO_SB",
                    $sformatf("READ SUCCESS: Actual_Data=%0d | Expected_Data=%0d", tx.data_out,exp_data),
            UVM_MEDIUM)
      end
          if(tx.full !== (exp_q.size() == cfg.count))
      `uvm_error("FIFO_SB","FULL FLAG MISMATCH")

    if(tx.empty !== (exp_q.size() == 0))
      `uvm_error("FIFO_SB","EMPTY FLAG MISMATCH")

    end
	

  
  endtask

  function void extract_phase(uvm_phase phase);
    super.extract_phase(phase);

    `uvm_info("FIFO_SB",
      $sformatf("Remaining elements in reference queue = %0d",
                exp_q.size()), UVM_LOW)
  endfunction

endclass
        
class virtual_sequencer extends uvm_sequencer#(uvm_sequence_item);
  `uvm_component_utils(virtual_sequencer)
  
  fifo_sequencer seqrh;
  
  function new(string name = "virtual_sequencer",
               uvm_component parent);
    super.new(name,parent);
  endfunction
endclass

class fifo_env extends uvm_env;
  `uvm_component_utils(fifo_env)
  
  fifo_agent agnth;
  virtual_sequencer v_seqrh;
  fifo_scoreboard sbh;
  
  function new(string name = "fifo_env",
               uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agnth = fifo_agent::type_id::create("agnth",this);
    sbh = fifo_scoreboard::type_id::create("sbh",this);
    v_seqrh = virtual_sequencer::type_id::create("v_seqrh",this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    v_seqrh.seqrh = agnth.seqrh;
    agnth.monh.mon_ap.connect(sbh.fifoh.analysis_export);
  endfunction
endclass
        
class fifo_vbase_seq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(fifo_vbase_seq)

  fifo_reset_seq rst_seq;
  fifo_write_seq wr_seq;
  fifo_read_seq rd_seq;
  fifo_wr_rd_seq wr_rd_seq;

  virtual_sequencer v_seqrh;
  fifo_sequencer seqrh;

  function new(string name = "fifo_vbase_seq");
    super.new(name);
  endfunction

  task body();
    if(!$cast(v_seqrh, m_sequencer)) begin
      `uvm_fatal("IN_VSEQ", "Casting failed")
    end

    seqrh = v_seqrh.seqrh;
  endtask

endclass
        
class v_rst_seq extends fifo_vbase_seq;
  `uvm_object_utils(v_rst_seq)

  function new(string name = "v_rst_seq");
    super.new(name);
  endfunction

  task body();
    super.body();

    rst_seq = fifo_reset_seq::type_id::create("rst_seq");

    rst_seq.start(seqrh);
  endtask

endclass
        
class v_wr_seq extends fifo_vbase_seq;
  `uvm_object_utils(v_wr_seq)

  function new(string name = "v_wr_seq");
    super.new(name);
  endfunction

  task body();
    super.body();

    wr_seq = fifo_write_seq::type_id::create("wr_seq");

    wr_seq.start(seqrh);
  endtask

endclass
 
class v_rd_seq extends fifo_vbase_seq;
  `uvm_object_utils(v_rd_seq)

  function new(string name = "v_rd_seq");
    super.new(name);
  endfunction

  task body();
    super.body();

    rd_seq = fifo_read_seq::type_id::create("rd_seq");

    rd_seq.start(seqrh);
  endtask

endclass
        
class v_wr_rd_seq extends fifo_vbase_seq;
  `uvm_object_utils(v_wr_rd_seq)

  function new(string name = "v_wr_rd_seq");
    super.new(name);
  endfunction

  task body();
    super.body();

    wr_rd_seq = fifo_wr_rd_seq::type_id::create("wr_rd_seq");

    wr_rd_seq.start(seqrh);
  endtask

endclass
        
class fifo_base_test extends uvm_test;
  `uvm_component_utils(fifo_base_test)
  
  fifo_config cfg;
  fifo_env envh;
  
  function new(string name = "fifo_base_test",
               uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = fifo_config::type_id::create("cfg");
    
    cfg.is_active = UVM_ACTIVE;
    cfg.count = `DEPTH;
    
    if(!uvm_config_db#(virtual fifo_if)::get(this,"","vif",cfg.vif))
      `uvm_fatal("IN_TST","get failed ,check once");
    
    uvm_config_db#(fifo_config)::set(this,"*","fifo_config",cfg);
    
    envh = fifo_env::type_id::create("envh",this);
  endfunction
endclass
        
class fifo_reset_test extends fifo_base_test;
  `uvm_component_utils(fifo_reset_test)

  v_rst_seq rst_vseq;

  function new(string name = "fifo_reset_test",
               uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    rst_vseq = v_rst_seq::type_id::create("rst_vseq");
    rst_vseq.start(envh.v_seqrh);

    phase.drop_objection(this);
  endtask

endclass        
          
class fifo_write_test extends fifo_base_test;
  `uvm_component_utils(fifo_write_test)

  v_wr_seq wr_vseq;
  v_rst_seq rst_vseq;
  v_rd_seq rd_vseq;
  v_wr_rd_seq  wr_rd_vseq;

  function new(string name = "fifo_write_test",
               uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
  rst_vseq = v_rst_seq::type_id::create("rst_vseq");
    rst_vseq.start(envh.v_seqrh,,400);

    wr_vseq = v_wr_seq::type_id::create("wr_vseq");
    wr_vseq.start(envh.v_seqrh,,300);
    
    rd_vseq = v_rd_seq::type_id::create("rd_vseq");

    rd_vseq.start(envh.v_seqrh,,200);
    
     wr_rd_vseq = v_wr_rd_seq::type_id::create("wr_rd_vseq");
    wr_rd_vseq.start(envh.v_seqrh,,100);
    #20;
    
    phase.drop_objection(this);
  endtask

endclass
        
class fifo_read_test extends fifo_base_test;
  `uvm_component_utils(fifo_read_test)

  v_rd_seq rd_vseq;

  function new(string name = "fifo_read_test",
               uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    rd_vseq = v_rd_seq::type_id::create("rd_vseq");

    rd_vseq.start(envh.v_seqrh);

    phase.drop_objection(this);
  endtask

endclass
        
class fifo_wr_rd_test extends fifo_base_test;
  `uvm_component_utils(fifo_wr_rd_test)

  v_wr_rd_seq wr_rd_vseq;

  function new(string name = "fifo_wr_rd_test",
               uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    wr_rd_vseq = v_wr_rd_seq::type_id::create("wr_rd_vseq");
    wr_rd_vseq.start(envh.v_seqrh);

    phase.drop_objection(this);
  endtask

endclass
module fifo_tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  bit clk;

  always #5 clk = ~clk;

  fifo_if DUV(clk);

  fifo dut(
    .clk      (clk),
    .rst      (DUV.rst),
    .wr_en    (DUV.wr_en),
    .rd_en    (DUV.rd_en),
    .data_in  (DUV.data_in),
    .data_out (DUV.data_out),
    .full     (DUV.full),
    .empty    (DUV.empty)
  );

  initial begin
   $dumpfile("dump.vcd");
$dumpvars(0, fifo_tb_top);
    uvm_config_db#(virtual fifo_if)::set(
      null, "*", "vif",DUV);

    run_test("fifo_write_test");
  end
  

endmodule        
