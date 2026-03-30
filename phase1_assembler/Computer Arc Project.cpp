#include <iostream>   // For cout
#include <fstream>    // For file reading and writing
#include <string>     // For string
#include <vector>     // For vector
#include <map>        // For map
#include <sstream>    // For stringstream
#include <iomanip>    // For setw, setfill, hex
#include <cstdint>    // For uint32_t

using namespace std;

// This structure stores metadata for each instruction
// type   = instruction format (R, I, S, SB, UJ)
// opcode = opcode field
// f3     = funct3 field
// f7     = funct7 field
struct Meta {
    string type;
    int opcode, f3, f7;
};

// This map is the instruction table
// Key   = instruction mnemonic as string
// Value = metadata needed to encode that instruction
map<string, Meta> table = {
    {"addw",  {"R",  0x34, 1, 0x10}}, // addw rd, rs1, rs2
    {"addiw", {"I",  0x14, 1, 0}},    // addiw rd, rs1, imm

    {"and",   {"R",  0x34, 0, 0x10}}, // and rd, rs1, rs2
    {"andi",  {"I",  0x14, 0, 0}},    // andi rd, rs1, imm

    {"bge",   {"SB", 0x64, 6, 0}},    // bge rs1, rs2, label
    {"bne",   {"SB", 0x64, 2, 0}},    // bne rs1, rs2, label

    {"jal",   {"UJ", 0x70, 0, 0}},    // jal rd, label
    {"jalr",  {"I",  0x68, 1, 0}},    // jalr rd, rs1, imm

    {"lw",    {"I",  0x14, 3, 0}},    // lw rd, imm(rs1)

    {"xor",   {"R",  0x34, 5, 0x10}}, // xor rd, rs1, rs2
    {"or",    {"R",  0x34, 7, 0x10}}, // or rd, rs1, rs2
    {"ori",   {"I",  0x14, 7, 0}},    // ori rd, rs1, imm

    {"sltu",  {"R",  0x34, 4, 1}},    // sltu rd, rs1, rs2
    {"srl",   {"R",  0x34, 6, 0x10}}, // srl rd, rs1, rs2
    {"sra",   {"R",  0x34, 6, 0x30}}, // sra rd, rs1, rs2

    {"sw",    {"S",  0x24, 3, 0}}     // sw rs2, imm(rs1)
};

// This map stores labels and their addresses
// Example: l1 -> 32
map<string, int> labels;

// ----------------------------------------------------------
// trim function
// Removes spaces and tabs from beginning and end of string
// ----------------------------------------------------------
string trim(const string& s) {
    size_t start = s.find_first_not_of(" \t\r\n");
    if (start == string::npos) return "";

    size_t end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
}

// ----------------------------------------------------------
// removeComment function
// Removes comment starting with #
// Example:
// "addiw x1, x0, 5 # comment"  -> "addiw x1, x0, 5"
// ----------------------------------------------------------
string removeComment(const string& s) {
    size_t pos = s.find('#');
    if (pos != string::npos) return s.substr(0, pos);
    return s;
}

// ----------------------------------------------------------
// cleanToken function
// Removes trailing comma from token if it exists
// Example: "x5," -> "x5"
// ----------------------------------------------------------
string cleanToken(string s) {
    if (!s.empty() && s.back() == ',') s.pop_back();
    return s;
}

// ----------------------------------------------------------
// reg function
// Converts register string to register number
// Example: "x5" -> 5
// ----------------------------------------------------------
int reg(string s) {
    s = cleanToken(s);

    if (!s.empty() && s[0] == 'x') {
        return stoi(s.substr(1));
    }

    return stoi(s);
}

int main() {
    string line;
    int pc = 0;

    // Hardcoded paths for input and output files
    // Change these if the project folder is moved to another place
    string inputPath = "input.txt";
    string outputPath = "output.txt";

    // ======================================================
    // PASS 1
    // Read the file and collect label addresses
    // ======================================================
    ifstream pass1(inputPath);

    if (!pass1.is_open()) {
        cout << "Error opening input file!" << endl;
        return 1;
    }

    while (getline(pass1, line)) {
        // Remove comments and extra spaces
        line = removeComment(line);
        line = trim(line);

        // Ignore empty lines
        if (line.empty()) continue;

        // Check if the line contains a label
        // Supports:
        // 1) label alone:  l1:
        // 2) label + instruction: l1: addiw x1, x0, 5
        size_t colonPos = line.find(':');

        if (colonPos != string::npos) {
            // Extract label name before :
            string label = trim(line.substr(0, colonPos));

            // Store label with current PC value
            labels[label] = pc;

            // Extract the rest of line after :
            string rest = trim(line.substr(colonPos + 1));

            // If there is an instruction after the label, count it
            if (!rest.empty()) {
                pc += 4;
            }
        }
        else {
            // If it is a normal instruction line, increment PC by 4
            pc += 4;
        }
    }

    pass1.close();

    // ======================================================
    // PASS 2
    // Read the file again and translate instructions
    // ======================================================
    ifstream pass2(inputPath);
    ofstream output(outputPath);

    if (!pass2.is_open()) {
        cout << "Error opening input file in pass 2!" << endl;
        return 1;
    }

    if (!output.is_open()) {
        cout << "Error creating output file!" << endl;
        return 1;
    }

    // Reset PC to zero for second pass
    pc = 0;

    while (getline(pass2, line)) {
        // Remove comments and trim spaces
        line = removeComment(line);
        line = trim(line);

        // Ignore empty lines
        if (line.empty()) continue;

        // If line contains label, skip label part
        size_t colonPos = line.find(':');
        if (colonPos != string::npos) {
            line = trim(line.substr(colonPos + 1));

            // If label-only line, continue to next line
            if (line.empty()) continue;
        }

        // Read instruction mnemonic
        stringstream ss(line);
        string name;
        ss >> name;
        name = cleanToken(name);

        // Check that instruction exists in table
        if (table.find(name) == table.end()) {
            cout << "Unsupported instruction: " << name << endl;
            return 1;
        }

        // Get metadata for this instruction
        Meta m = table[name];

        // This variable will hold the final 32-bit machine code
        uint32_t mc = 0;

        // Temporary variables for registers, target label, and immediate
        string r1, r2, r3, target;
        int imm = 0;

        // --------------------------------------------------
        // R-type instructions
        // Format: [funct7 | rs2 | rs1 | funct3 | rd | opcode]
        // Syntax: instr rd, rs1, rs2
        // --------------------------------------------------
        if (m.type == "R") {
            ss >> r1 >> r2 >> r3;

            mc = (m.f7 << 25)         // funct7 goes to bits 31:25
                | (reg(r3) << 20)     // rs2 goes to bits 24:20
                | (reg(r2) << 15)     // rs1 goes to bits 19:15
                | (m.f3 << 12)        // funct3 goes to bits 14:12
                | (reg(r1) << 7)      // rd goes to bits 11:7
                | m.opcode;           // opcode goes to bits 6:0
        }

        // --------------------------------------------------
        // I-type instructions
        // Format: [imm[11:0] | rs1 | funct3 | rd | opcode]
        // Syntax for normal I-type: instr rd, rs1, imm
        // Syntax for lw: lw rd, imm(rs1)
        // --------------------------------------------------
        else if (m.type == "I") {
            if (name == "lw") {
                // lw rd, imm(rs1)
                string combined;
                ss >> r1 >> combined;

                size_t paren = combined.find('(');

                // immediate is the part before '('
                imm = stoi(combined.substr(0, paren));

                // rs1 is inside parentheses
                r2 = combined.substr(paren + 1, combined.find(')') - paren - 1);
            }
            else {
                // normal I-type form
                ss >> r1 >> r2 >> imm;
            }

            mc = ((imm & 0xFFF) << 20) // 12-bit immediate to bits 31:20
                | (reg(r2) << 15)      // rs1 to bits 19:15
                | (m.f3 << 12)         // funct3 to bits 14:12
                | (reg(r1) << 7)       // rd to bits 11:7
                | m.opcode;            // opcode to bits 6:0
        }

        // --------------------------------------------------
        // S-type instructions
        // Format: [imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode]
        // Syntax: sw rs2, imm(rs1)
        // --------------------------------------------------
        else if (m.type == "S") {
            string combined;
            ss >> r2 >> combined;

            size_t paren = combined.find('(');

            // immediate is before '('
            imm = stoi(combined.substr(0, paren));

            // rs1 is inside parentheses
            r1 = combined.substr(paren + 1, combined.find(')') - paren - 1);

            mc = (((imm >> 5) & 0x7F) << 25) // imm[11:5]
                | (reg(r2) << 20)            // rs2
                | (reg(r1) << 15)            // rs1
                | (m.f3 << 12)               // funct3
                | ((imm & 0x1F) << 7)        // imm[4:0]
                | m.opcode;                  // opcode
        }

        // --------------------------------------------------
        // SB-type instructions
        // Format: [imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode]
        // Syntax: bge/bne rs1, rs2, label
        // --------------------------------------------------
        else if (m.type == "SB") {
            ss >> r1 >> r2 >> target;
            target = cleanToken(target);

            // If target is a label, use label address - current PC
            // Otherwise assume it is a direct immediate number
            imm = labels.count(target) ? labels[target] - pc : stoi(target);

            // Extract branch immediate fields
            int b12 = (imm >> 12) & 1;
            int b11 = (imm >> 11) & 1;
            int b10_5 = (imm >> 5) & 0x3F;
            int b4_1 = (imm >> 1) & 0xF;

            mc = (b12 << 31)         // imm[12]
                | (b10_5 << 25)      // imm[10:5]
                | (reg(r2) << 20)    // rs2
                | (reg(r1) << 15)    // rs1
                | (m.f3 << 12)       // funct3
                | (b4_1 << 8)        // imm[4:1]
                | (b11 << 7)         // imm[11]
                | m.opcode;          // opcode
        }

        // --------------------------------------------------
        // UJ-type instructions
        // Format: [imm[20|10:1|11|19:12] | rd | opcode]
        // Syntax: jal rd, label
        // --------------------------------------------------
        else if (m.type == "UJ") {
            ss >> r1 >> target;
            target = cleanToken(target);

            // If target is a label, calculate relative address
            // Otherwise assume direct immediate
            imm = labels.count(target) ? labels[target] - pc : stoi(target);

            // Extract jump immediate fields
            int j20 = (imm >> 20) & 1;
            int j19_12 = (imm >> 12) & 0xFF;
            int j11 = (imm >> 11) & 1;
            int j10_1 = (imm >> 1) & 0x3FF;

            mc = (j20 << 31)         // imm[20]
                | (j10_1 << 21)      // imm[10:1]
                | (j11 << 20)        // imm[11]
                | (j19_12 << 12)     // imm[19:12]
                | (reg(r1) << 7)     // rd
                | m.opcode;          // opcode
        }

        // Write machine code to output file in hexadecimal
        output << uppercase << hex << setw(8) << setfill('0') << mc << endl;

        // Move to next instruction address
        pc += 4;
    }

    pass2.close();
    output.close();

    cout << "Assembly complete. Check output.txt" << endl;
    return 0;
}