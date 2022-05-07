import axi_vip_pkg::*;
import axi_int_test_bd_axi_vip_0_0_pkg::*;

module axi_int_test_tb #(parameter test_mode = 1);

bit aclk;
bit aresetn;
wire interrupt;

axi_int_test_bd dut(
    .ACLK(aclk),
    .ARESETN(aresetn),
    .INTERRUPT(interrupt)
);

initial begin
    aresetn <= 1'b1;
end

always #10 aclk <= ~aclk;

generate if (test_mode == 1) begin: init
    axi_int_test_bd_axi_vip_0_0_mst_t agent;

    initial begin
        agent = new(
            "master vip agent",
            dut.axi_vip_0.inst.IF
        ); 
            
        agent.start_master();

        fork
            wr_response();
        join_none
    end
    
    task wr_response();
        axi_transaction transaction;  

        transaction = agent.wr_driver.create_transaction("write transaction");

        WR_TRANSACTION_FAIL_1b: assert(transaction.randomize());
        agent.wr_driver.send(transaction);
        
//        axi_transaction transaction;  
        
//        transaction = mst_agent.wr_driver.create_transaction("write transaction");
//        transaction.set_write_cmd(mtestADDR, mtestBurstType, mtestID,
//mtestBurstLength,mtestDataSize);
//wr_transaction.set_data_block(mtestWData);
//for(int beat=0; beat<wr_transaction.get_len()+1; beat++) begin
//wr_transaction.set_data_beat(beat, dbeat);
//end
//mst_agent.wr_driver.send(wr_transaction);
        
//            forever begin                                   
//                agent.wr_driver.get_wr_reactive (wr_reactive); 
//                fill_wr_reactive                (wr_reactive); 
//                agent.wr_driver.send            (wr_reactive); 
//            end
    endtask
end endgenerate

endmodule