using DelimitedFiles 

include("dnn_to_milp.jl")

node_file = "../data/Bias_1.csv"
edge_file = "../data/Node_1.csv"
range_file = "../data/Ranges_1.csv"
num_layers = 4
num_nodes_in_layer = [6, 20, 20, 1]

function read_and_populate_model(node_file, edge_file, range_file, 
    num_layers, num_nodes_in_layer; has_final_output_bias = true)
    
    biases = create_empty_biases(num_layers, num_nodes_in_layer)
    weights = create_empty_weights(num_layers, num_nodes_in_layer)
    ranges = []

    bias_data = readdlm(node_file)
    weight_data = readdlm(edge_file)
    range_data = readdlm(range_file)
    
    for row in bias_data[2:end]
        values = map(x -> parse(Float64, x), split(row, ","))
        layer_id = Int(values[1])
        node_id = Int(values[2])
        b = values[3]
        biases[layer_id][node_id] = b
    end 

    for row in weight_data[2:end]
        values = map(x -> parse(Float64, x), split(row, ","))
        layer_id = Int(values[1])
        f = Int(values[3])
        t = Int(values[4])
        w = values[5]
        weights[layer_id][EdgeId(f, t)] = w 
    end 

    for row in range_data[2:end]
        values = map(x -> parse(Float64, x), split(row, ","))
        push!(ranges, (values[1], values[2]))
    end 

    input_range = ranges[1:6]
    output_range = ranges[7]

    @info "reading completed"

    m, var  = get_milp(num_layers, num_nodes_in_layer, weights, biases, 
        input_range, output_range)

    @info "MILP created"
    return m, var
    
end 

m, var = read_and_populate_model(node_file, edge_file, range_file, num_layers, num_nodes_in_layer)

input = var[:input]
output = var[:output]
x = var[:x]

data = [3.0, 0.3, 50.0, 0.1, 0.5330, 500.0]

set_input(m, input, data)

solve_model(m)

println("output value: $(JuMP.value(output))")

# original output: 0.0998



