// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

///////////////////////////////////////////////////////////////////////////////
//
// Description: Configuration registers for parallel camera interface
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Antonio Pullini (pullinia@iis.ee.ethz.ch)
//
///////////////////////////////////////////////////////////////////////////////

`define REG_RX_SADDR     5'b00000 //BASEADDR+0x00
`define REG_RX_SIZE      5'b00001 //BASEADDR+0x04
`define REG_RX_CFG       5'b00010 //BASEADDR+0x08
`define REG_RX_INTCFG    5'b00011 //BASEADDR+0x0C

`define REG_TX_SADDR     5'b00100 //BASEADDR+0x10
`define REG_TX_SIZE      5'b00101 //BASEADDR+0x14
`define REG_TX_CFG       5'b00110 //BASEADDR+0x18
`define REG_TX_INTCFG    5'b00111 //BASEADDR+0x1C

`define REG_CAM_CFG_GLOB    5'b01000 //BASEADDR+0x20
`define REG_CAM_CFG_LL      5'b01001 //BASEADDR+0x24
`define REG_CAM_CFG_UR      5'b01010 //BASEADDR+0x28
`define REG_CAM_CFG_SIZE    5'b01011 //BASEADDR+0x2C

`define REG_CAM_CFG_FILTER  5'b01100 //BASEADDR+0x30
`define REG_CAM_VSYNC_POLARITY  5'b01101 //BASEADDR+0x34
`define REG_DST          5'b01110 //BASEADDR+0x38

module camera_reg_if 
    import udma_pkg::*;
#(
    parameter L2_AWIDTH_NOAL = 12,
    parameter TRANS_SIZE     = 16
) (
    input  logic                      clk_i,
    input  logic                      rstn_i,

    input  logic               [31:0] cfg_data_i,
    input  logic                [4:0] cfg_addr_i,
    input  logic                      cfg_valid_i,
    input  logic                      cfg_rwn_i,
    output logic               [31:0] cfg_data_o,
    output logic                      cfg_ready_o,

    output logic [L2_AWIDTH_NOAL-1:0] cfg_rx_startaddr_o,
    output logic     [TRANS_SIZE-1:0] cfg_rx_size_o,
    output logic                [1:0] cfg_rx_datasize_o,
    output logic                      cfg_rx_continuous_o,
    output logic                      cfg_rx_en_o,
    output logic                      cfg_rx_clr_o,
    input  logic                      cfg_rx_en_i,
    input  logic                      cfg_rx_pending_i,
    input  logic [L2_AWIDTH_NOAL-1:0] cfg_rx_curr_addr_i,
    input  logic     [TRANS_SIZE-1:0] cfg_rx_bytes_left_i,
    output ch_dest_t                  cfg_rx_dest_o,

    input  logic                      cfg_cam_ip_en_i,
    output logic                      cfg_cam_vsync_polarity_o,
    output logic             [31 : 0] cfg_cam_cfg_o,
    output logic             [31 : 0] cfg_cam_cfg_ll_o,
    output logic             [31 : 0] cfg_cam_cfg_ur_o,
    output logic             [31 : 0] cfg_cam_cfg_size_o,
    output logic             [31 : 0] cfg_cam_cfg_filter_o
);

    logic [L2_AWIDTH_NOAL-1:0] r_rx_startaddr;
    logic   [TRANS_SIZE-1 : 0] r_rx_size;
    logic              [1 : 0] r_rx_datasize;
    logic                      r_rx_continuous;
    logic                      r_rx_en;
    logic                      r_rx_clr;

    logic [31:0]               r_cam_cfg;
    logic [31:0]               r_cam_cfg_ll;
    logic [31:0]               r_cam_cfg_ur;
    logic [31:0]               r_cam_cfg_size;
    logic [31:0]               r_cam_cfg_filter;
    logic                      r_cam_vsync_polarity;

    logic                [4:0] s_wr_addr;
    logic                [4:0] s_rd_addr;

    ch_dest_t                  r_rx_dest;

    assign s_wr_addr = (cfg_valid_i & ~cfg_rwn_i) ? cfg_addr_i : 5'h0;
    assign s_rd_addr = (cfg_valid_i &  cfg_rwn_i) ? cfg_addr_i : 5'h0;

    assign cfg_rx_startaddr_o  = r_rx_startaddr;
    assign cfg_rx_size_o       = r_rx_size;
    assign cfg_rx_datasize_o   = r_rx_datasize;
    assign cfg_rx_continuous_o = r_rx_continuous;
    assign cfg_rx_en_o         = r_rx_en;
    assign cfg_rx_clr_o        = r_rx_clr;

    assign cfg_cam_cfg_o        = r_cam_cfg;
    assign cfg_cam_cfg_ll_o     = r_cam_cfg_ll;
    assign cfg_cam_cfg_ur_o     = r_cam_cfg_ur;
    assign cfg_cam_cfg_size_o   = r_cam_cfg_size;
    assign cfg_cam_cfg_filter_o = r_cam_cfg_filter;
    assign cfg_cam_vsync_polarity_o = r_cam_vsync_polarity;

    assign cfg_rx_dest_o   = r_rx_dest;


    always_ff @(posedge clk_i, negedge rstn_i)
    begin
        if(~rstn_i)
        begin
            // SPI REGS
            r_rx_startaddr   <=  'h0;
            r_rx_size        <=  'h0;
            r_rx_continuous  <=  'h0;
            r_rx_en           =  'h0;
            r_rx_clr          =  'h0;
            r_rx_datasize    <=  'b0;
            r_rx_dest        <=  'h0;
            r_cam_cfg        <=  'h0;
            r_cam_cfg_ll     <=  'h0;
            r_cam_cfg_ur     <=  'h0;
            r_cam_cfg_size   <=  'h0;
            r_cam_cfg_filter <=  'h0;

            r_cam_vsync_polarity <=  1'b0;
        end
        else
        begin
            r_rx_en         =  'h0;
            r_rx_clr        =  'h0;

            if (cfg_valid_i & ~cfg_rwn_i)
            begin
                case (s_wr_addr)
                `REG_RX_SADDR:
                    r_rx_startaddr   <= cfg_data_i[L2_AWIDTH_NOAL-1:0];
                `REG_RX_SIZE:
                    r_rx_size        <= cfg_data_i[TRANS_SIZE-1:0];
                `REG_RX_CFG:
                begin
                    r_rx_clr          = cfg_data_i[6];
                    r_rx_en           = cfg_data_i[4];
                    r_rx_datasize    <= cfg_data_i[2:1];
                    r_rx_continuous  <= cfg_data_i[0];
                end
                `REG_CAM_CFG_GLOB:
                    r_cam_cfg               <=  cfg_data_i;
                `REG_CAM_CFG_LL:
                    r_cam_cfg_ll            <=  cfg_data_i;
                `REG_CAM_CFG_UR:
                    r_cam_cfg_ur            <=  cfg_data_i;
                `REG_CAM_CFG_SIZE:
                    r_cam_cfg_size          <=  cfg_data_i;
                `REG_CAM_CFG_FILTER:
                    r_cam_cfg_filter        <=  cfg_data_i;
                `REG_CAM_VSYNC_POLARITY:
                    r_cam_vsync_polarity    <=  cfg_data_i[0];
                `REG_DST:
                begin
                    r_rx_dest         <= cfg_data_i[DEST_SIZE-1:0];
                end
                endcase
            end
        end
    end //always

    always_comb
    begin
        cfg_data_o = 32'h0;
        case (s_rd_addr)
        `REG_RX_SADDR:
            cfg_data_o = cfg_rx_curr_addr_i;
        `REG_RX_SIZE:
            cfg_data_o[TRANS_SIZE-1:0] = cfg_rx_bytes_left_i;
        `REG_RX_CFG:
            cfg_data_o = {26'h0,cfg_rx_pending_i,cfg_rx_en_i, 1'b0,r_rx_datasize,r_rx_continuous};
        `REG_CAM_CFG_GLOB:
            cfg_data_o = {cfg_cam_ip_en_i,r_cam_cfg[30:0]};
        `REG_CAM_CFG_LL:
            cfg_data_o = r_cam_cfg_ll;
        `REG_CAM_CFG_UR:
            cfg_data_o = r_cam_cfg_ur;
        `REG_CAM_CFG_SIZE:
            cfg_data_o = r_cam_cfg_size;
        `REG_CAM_CFG_FILTER:
            cfg_data_o = r_cam_cfg_filter;
        `REG_CAM_VSYNC_POLARITY:
            cfg_data_o = {31'h0, r_cam_vsync_polarity};
        `REG_DST:
            cfg_data_o = 32'h00000000 | r_rx_dest;
        default:
            cfg_data_o = 'h0;
        endcase
    end

    assign cfg_ready_o  = 1'b1;


endmodule
