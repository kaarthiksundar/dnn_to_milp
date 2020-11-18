using DelimitedFiles 

include("dnn_to_milp.jl")

node_file = "../data/Bias_1.csv"
edge_file = "../data/Node_1.csv"
num_layers = 4
num_nodes_in_layer = [6, 20, 20, 1]

function read_and_populate_model(node_file, 
    edge_file, num_layers, num_nodes_in_layer; 
    has_final_output_bias = true)
    
    biases = create_empty_biases(num_layers, num_nodes_in_layer)
    weights = create_empty_weights(num_layers, num_nodes_in_layer)

    bias_data = readdlm(node_file)
    weight_data = readdlm(edge_file)
    
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

    @info "reading completed"

    m, input, output = get_milp(num_layers, num_nodes_in_layer, weights, biases)

    @info "MILP created"
    return m, input, output
    

end 

m, input, output = read_and_populate_model(node_file, edge_file, num_layers, num_nodes_in_layer)