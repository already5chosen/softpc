set tcm_rdaddr_reg "altsyncram:mem|altsyncram_2ir3:auto_generated|ram_block*~portb_address_reg0"
set rf_we_reg      "nios2ee:cpu|n2register_file:rf|altsyncram:rf_rtl_0|altsyncram_tod1:auto_generated|ram_block1a0~porta_we_reg"
set rf_wraddr_reg  "nios2ee:cpu|n2register_file:rf|altsyncram:rf_rtl_0|altsyncram_tod1:auto_generated|ram_block1a0~porta_address_reg0"
set rf_wrdata_reg  "nios2ee:cpu|n2register_file:rf|altsyncram:rf_rtl_0|altsyncram_tod1:auto_generated|ram_block1a0~porta_datain_reg0"
set rf_rdaddr_reg  "nios2ee:cpu|n2register_file:rf|altsyncram:rf_rtl_0|altsyncram_fcc1:auto_generated|ram_block1a0~portb_address_reg0"


set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|alu_sh_result[*]} -setup -end 3
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|alu_sh_result[*]} -hold -end 2

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|n2program_counter:iu|nextpc[*]} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|n2program_counter:iu|nextpc[*]} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|n2program_counter:iu|addr_reg[*]} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|n2program_counter:iu|addr_reg[*]} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|PH_Regfile2} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|PH_Regfile2} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|PH_Execute} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|PH_Execute} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|PH_Fetch} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|PH_Fetch} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|PH_Branch} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|PH_Branch} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|src_sel_ab} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|src_sel_ab} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|dstreg_wren} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|dstreg_wren} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|is_br_reg} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|is_br_reg} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|is_load} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|is_load} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|is_store} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|is_store} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|lsu_op_reg[*]} -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|lsu_op_reg[*]} -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to $rf_we_reg -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to $rf_we_reg -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to $rf_wraddr_reg -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to $rf_wraddr_reg -hold -end 1

set_multicycle_path -from $tcm_rdaddr_reg -to $rf_wrdata_reg -setup -end 2
set_multicycle_path -from $tcm_rdaddr_reg -to $rf_wrdata_reg -hold -end 1

set_multicycle_path -from $rf_rdaddr_reg -to {nios2ee:cpu|alu_sh_result[*]} -setup -end 2
set_multicycle_path -from $rf_rdaddr_reg -to {nios2ee:cpu|alu_sh_result[*]} -hold -end 1

set_multicycle_path -from "nios2ee:cpu|reg_a[*]" -to {nios2ee:cpu|alu_sh_result[*]} -setup -end 2
set_multicycle_path -from "nios2ee:cpu|reg_a[*]" -to {nios2ee:cpu|alu_sh_result[*]} -hold -end 1

set_multicycle_path -from {nios2ee:cpu|src_sel_ab} -to {nios2ee:cpu|alu_sh_result[*]} -setup -end 2
set_multicycle_path -from {nios2ee:cpu|src_sel_ab} -to {nios2ee:cpu|alu_sh_result[*]} -hold -end 1

set_multicycle_path -from {nios2ee:cpu|is_srcreg_b_reg} -to {nios2ee:cpu|alu_sh_result[*]} -setup -end 2
set_multicycle_path -from {nios2ee:cpu|is_srcreg_b_reg} -to {nios2ee:cpu|alu_sh_result[*]} -hold -end 1

set_multicycle_path -from {nios2ee:cpu|is_b_zero} -to {nios2ee:cpu|alu_sh_result[*]} -setup -end 2
set_multicycle_path -from {nios2ee:cpu|is_b_zero} -to {nios2ee:cpu|alu_sh_result[*]} -hold -end 1

# set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|agu_result[*]} -setup -end 3
# set_multicycle_path -from $tcm_rdaddr_reg -to {nios2ee:cpu|agu_result[*]} -hold -end 2
# 
# set_multicycle_path -from $rf_rdaddr_reg -to {nios2ee:cpu|agu_result[*]} -setup -end 2
# set_multicycle_path -from $rf_rdaddr_reg -to {nios2ee:cpu|agu_result[*]} -hold -end 1

