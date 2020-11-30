using DelimitedFiles 
using ArgParse

include("dnn_to_milp.jl")
include("overlap_percent.jl")
include("types.jl")
include("data_parsing.jl")
include("sensor_placement.jl")
include("writer.jl")

function ArgParse.parse_item(::Vector{Int}, x::AbstractString)
    a = split(x, ('[', ']', ',', ' '))
    b = []
    for i in a 
        (i == "") && (continue) 
        push!(b, parse(Int64, i))
    end 
    return b 
end

s = ArgParseSettings()
@add_arg_table s begin
    "--node_file"
        help = "DNN node bias data file"
        arg_type = String 
        default = "./data/Bias_1.csv"
    "--edge_file"
        help = "DNN edge weight data file"
        arg_type = String
        default = "./data/Node_1.csv"
    "--range_file"
        help = "DNN file for normalizing inputs"
        arg_type = String 
        default = "./data/Ranges_1.csv"
    "--pmax"
        help = "required pmax (default = 0.1)"
        arg_type = Float64 
        default = 0.1
    "--num_layers"
        help = "number of layers including input and output layers in DNN"
        arg_type = Int 
        default = 4
    "--num_nodes_in_layer"
        help = "number of nodes in each layer" 
        arg_type = Vector{Int}
        default = [6, 20, 20, 1]
    "--casefile" 
        help = "case file for tunnel orientation"
        arg_type = String 
        default = "./data/testcases/TestCase_7.csv"
    "--wallcasefile"
        help = "data for walls"
        arg_type = String 
        default = "./data/retestcases/WallWPs_7.csv"
    "--output_straight"
        help = "output filename for straight placement"
        arg_type = String 
        default = "./output/straight_7.csv"
    "--output_optimal"
        help = "output filename for optimal placement"
        arg_type = String 
        default = "./output/optimal_7.csv"
end

parsed_args = parse_args(ARGS, s)

node_file = parsed_args["node_file"]
edge_file = parsed_args["edge_file"]
range_file = parsed_args["range_file"]
num_layers = parsed_args["num_layers"]
num_nodes_in_layer = parsed_args["num_nodes_in_layer"]
case_file = parsed_args["casefile"]
wall_case_file = parsed_args["wallcasefile"]

case_data = readdlm(case_file)

op = get_overlap_percentage(parsed_args)

drop_distance = case_data[3] * (1 - op)

@info "overlap percentage: $(round(op, digits=4))"
@info "drop distance: $(round(drop_distance, digits=2))"


tunnel_data = get_data(parsed_args)

straight_placement = get_straight_placements(tunnel_data, drop_distance)

over_placement = get_over_placements(tunnel_data, straight_placement, drop_distance)

op_placement = get_optimal_placements(tunnel_data, 
    straight_placement, drop_distance)

write_placement(op_placement, op; file = parsed_args["output_optimal"])
write_placement(straight_placement, op; file = parsed_args["output_straight"])


