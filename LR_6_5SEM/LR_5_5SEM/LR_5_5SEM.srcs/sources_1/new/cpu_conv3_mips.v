`define PC_WIDTH 10
`define COMMAND_SIZE 46
`define PROGRAM_SIZE 1024 // 1024
`define DATA_SIZE 1024 // 1024
`define OP_SIZE 4
`define ADDR_SIZE 10

`define NOP 0
`define LOAD 1
`define ADD 2
`define SUB 3
`define JMP_GZ 4

`define INCR 5
`define CMP 6
`define MOV 7
`define JMP_NZ 8
`define MUL 9
//`define RAR 10
//`define RAL 11
`define MOD 10
`define DIV 11
`define JMP 12
`define JMP_RL 13
`define CALL 14
`define RET 15

/*
    Формат команды:
    ADD, SUB, NOP, MUL, DIV, MOD:
    | код операции  | Адрес 1            | Адрес 2         | Адрес 3
         4 бита     | 10 бит             | 10 бит          | 10 бит
    CMP, MOV:
    | код операции  | Адрес 1            | Адрес 2         |        
         4 бита     | 10 бит             | 10 бит          | 20 бит
    INCR, RAR, RAL:
    | код операции  | Адрес 1            |        
         4 бита     | 10 бит             |           32 бита
    LOAD:
    | код операции  |  адрес в памяти    |           Литерал             |
         4 бита     |     10 бит         |            32 бита            |
    JMP_GZ, JMP_RL, RET, JMP:
    | код операции  |           Адрес перехода      |                        |
         4 бита     |            10 бит             |       32 бита          |
    CALL, RET:
    | код операции  |          Адрес перехода       |      Адрес 2   |---Адрес 3   |
    |     4 бита     |           10 бит             |        10 бит  |    10 бит   |  10 бит
*/


module cpu_conv3_mips(
    input clk_in,
    input reset,
    output pc
);

wire clk;
reg[`PC_WIDTH-1 : 0] pc, newpc;


reg [`COMMAND_SIZE-1 : 0]   Program [0:`PROGRAM_SIZE - 1  ];
reg [31:0]                  Data    [0:`DATA_SIZE - 1];

reg[`COMMAND_SIZE-1 : 0] command_1, command_2, command_3;
wire [`OP_SIZE - 1 : 0] op_2 = command_2 [`COMMAND_SIZE - 1 -: `OP_SIZE];
wire [`OP_SIZE - 1 : 0] op_3 = command_3 [`COMMAND_SIZE - 1 -: `OP_SIZE];

wire [`ADDR_SIZE - 1 : 0] addr1 = command_2[`COMMAND_SIZE - 1 - `OP_SIZE                 -: `ADDR_SIZE];
wire [`ADDR_SIZE - 1 : 0] addr2 = command_2[`COMMAND_SIZE - 1 - `OP_SIZE - `ADDR_SIZE    -: `ADDR_SIZE];

wire [$clog2(`DATA_SIZE) - 1 : 0] new_addr = command_3 [`COMMAND_SIZE - 1 - `OP_SIZE -: $clog2(`DATA_SIZE)];
wire [$clog2(`DATA_SIZE) - 1 : 0] addr_to_load = command_3 [`COMMAND_SIZE - 1 - `OP_SIZE - `ADDR_SIZE - `ADDR_SIZE -: $clog2(`DATA_SIZE)];
wire [$clog2(`DATA_SIZE) - 1 : 0] addr_to_load_L = command_3 [`COMMAND_SIZE - 1 - `OP_SIZE  -: `ADDR_SIZE];

wire [31:0] literal_to_load = command_3 [`COMMAND_SIZE - 1 - `OP_SIZE - $clog2(`DATA_SIZE) -: 32];
reg [31:0] Reg_A, Reg_B, newReg_A, newReg_B;
reg flag_GZ, new_flag_GZ;
reg flag_NZ, new_flag_NZ;
reg flag_C_L, new_flag_C_L;
reg flag_C_R, new_flag_C_R;

reg [9:0] STECK_pointer;

integer i;
initial 
begin
    pc = 0; newpc = 0;
    $readmemb("Program_LR_6_1.mem", Program);
    for(i = 0; i < `DATA_SIZE; i = i + 1)
        Data[i] = 32'b0;
    command_1 = 0;
    command_2 = 0;
    command_3 = 0;
    Reg_A = 0;
    Reg_B = 0;
    newReg_A = 0; 
    newReg_B = 0;
    flag_C_R = 0;
    new_flag_C_R = 0;
    flag_C_L = 0;
    new_flag_C_L = 0;
    
    STECK_pointer = 128;
end

clk_wiz_0 inst(
    .clk_in1(clk_in),
    .clk_out1(clk)
);

//Блок управления счётчиком команд
always@(posedge clk)
    if(reset)
        pc <= 0;
    else
        pc <= newpc;


//Такт 2
//Изменение регистра A
always @(posedge clk)
begin 
    if(reset) Reg_A <= 0;
    else Reg_A <= newReg_A;
end

//Изменение регистра B
always @(posedge clk)
begin 
    if(reset) Reg_B <= 0;
    else Reg_B <= newReg_B;
end


always @*
begin
    case(op_2)
        `ADD, `SUB:
            if(addr1 == addr_to_load && (op_3 == `ADD || op_3 == `SUB) || addr1 == addr_to_load_L && (op_3 == `LOAD))
                newReg_A <= new_data;
            else newReg_A <= Data[addr1];
         `CMP: begin
            newReg_A = Data[addr1];
            newReg_A = Data[newReg_A];
            end
         `MUL: begin
            newReg_A = Data[addr1];
            newReg_A = Data[newReg_A];
            end
         `DIV: begin
            newReg_A = Data[addr1];
            newReg_A = Data[newReg_A];
            end
         `MOD: begin
            newReg_A = Data[addr1];
            newReg_A = Data[newReg_A];
            end
        default: newReg_A <= newReg_A;
    endcase
end

always @*
begin
    case(op_2)
        `ADD, `SUB:
            if(addr2 == addr_to_load && (op_3 == `ADD || op_3 == `SUB) || addr2 == addr_to_load_L && (op_3 == `LOAD))
                newReg_B <= new_data;
            else newReg_B <= Data[addr2];
        `CMP: begin
            newReg_B = Data[addr2];
            newReg_B = Data[newReg_B];
            end
        `MUL: begin
            newReg_B = Data[addr2];
            newReg_B = Data[newReg_B];
            end
        `DIV: begin
            newReg_B = Data[addr2];
            newReg_B = Data[newReg_B];
            end
        `MOD: begin
            newReg_B = Data[addr2];
            newReg_B = Data[newReg_B];
            end
        `MOV: begin
            newReg_B = Data[addr2];
            newReg_B = Data[newReg_B];
            end
        `CALL: begin
            newReg_A = Data[addr2];
            newReg_B = Data[addr2];
            newReg_B = Data[newReg_B];
            end
        `RET: begin
            newReg_B = Data[STECK_pointer];
            STECK_pointer = STECK_pointer - 1;
            newReg_A = Data[STECK_pointer];
            STECK_pointer = STECK_pointer - 1;
            end 
        default: newReg_B <= newReg_B;
    endcase
end

//Такт_3
reg [31:0] new_data;

always @(posedge clk)
begin
    case(op_3)
        `ADD, `SUB:
            Data[addr_to_load] <= new_data;
         `MOV:
            Data[Data[addr_to_load_L]] <= new_data;
         `MUL:
            Data[Data[addr_to_load]] <= new_data;
         `DIV: 
            Data[Data[addr_to_load]] <= new_data;
         `MOD:
            Data[Data[addr_to_load]] <= new_data;
         `INCR:
            Data[addr_to_load_L] <= new_data;
         `CALL: begin
            STECK_pointer = STECK_pointer + 1;
            Data[STECK_pointer] = pc + 1;
            STECK_pointer = STECK_pointer + 1;
            Data[STECK_pointer] = Reg_A;
            STECK_pointer = STECK_pointer + 1;
            Data[STECK_pointer] = new_data;
            end
         `RET: begin
            Data[Reg_A] <= Reg_B;
            end
//         `RAR:
//            Data[addr_to_load_L] <= new_data;
//         `RAL:
//            Data[addr_to_load_L] <= new_data;
         `LOAD:
            Data[addr_to_load_L] <= new_data;
    endcase
end

always @*
begin
    case(op_3)
        `ADD: new_data <= Reg_A + Reg_B;
        `SUB: new_data <= Reg_A - Reg_B;
        `MOV: new_data <= Reg_B;
        `MUL: new_data <= Reg_A * Reg_B;
        `DIV: new_data <= Reg_A / Reg_B;
        `INCR: new_data <= Data[addr_to_load_L] + 1;
        `MOD: new_data <= Reg_A % Reg_B;
        `CALL: new_data <= Reg_B;
//        `RAR: new_data <= {1'b0, Data[addr_to_load_L][31:1]};
//        `RAL: new_data <= {Data[addr_to_load_L][30:0], 1'b0};
        `LOAD: new_data <= literal_to_load;
    endcase
end

always @(posedge clk)
begin
    flag_GZ <= new_flag_GZ;
    flag_NZ <= new_flag_NZ;
    flag_C_L <= new_flag_C_L;
    flag_C_R <= new_flag_C_R;
end

always @*
begin 
    case(op_3)
        `ADD, `SUB: 
            new_flag_GZ <= ~(new_data < 0 || new_data == 0); // изменено на NGZ
        `CMP: begin
            new_flag_GZ <= Reg_A == Reg_B;
            new_flag_NZ <= ~(Reg_A == Reg_B || Reg_A < Reg_B);
            end
//         `RAR: begin
//            new_flag_C_R <= ~Data[addr_to_load_L][0];
//            end
//         `RAL: begin
//            new_flag_C_L <= ~Data[addr_to_load_L][31];
//            end
    endcase
end

//Блок определения следующего значения счётчика команд
always@*
begin
    if(op_3 == `JMP_GZ && (new_flag_GZ || new_flag_C_L))
        newpc <= new_addr;
    else if (op_3 == `JMP_NZ && new_flag_NZ)
        newpc <= new_addr;
    else if (op_3 == `JMP_RL && (new_flag_C_L == new_flag_C_R))
        newpc <= new_addr;
    else if (op_3 == `CALL) begin
        newpc = new_addr;
        end
    else if (op_3 == `RET) begin
        newpc = Data[STECK_pointer];
        STECK_pointer = STECK_pointer - 1;
        end
    else
        newpc <= pc + 1;
end

always@(posedge clk)
begin
    command_1 <= Program[pc];
    command_2 <= command_1;
    command_3 <= command_2;
end


endmodule
