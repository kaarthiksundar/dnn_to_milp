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

function get_overlap_percentage(args::Dict)::Float64 
    node_file = args["node_file"]
    edge_file = args["edge_file"]
    range_file = args["range_file"]
    num_layers = args["num_layers"]
    num_nodes_in_layer = args["num_nodes_in_layer"]
    case_file = args["casefile"]
    pmax_value = args["pmax"]

    m, var = read_and_populate_model(node_file, 
        edge_file, range_file, 
        num_layers, 
        num_nodes_in_layer)

    input = var[:input]
    output = var[:output]

    case_data = readdlm(case_file)

    @constraint(m, input[1] == case_data[1])
    @constraint(m, input[2] == case_data[2])
    @constraint(m, input[3] == case_data[3])
    @constraint(m, input[4] == case_data[4])
    @constraint(m, input[6] == case_data[5])

    JuMP.set_lower_bound(input[5], 0.05)
    JuMP.set_upper_bound(input[5], 0.75)
    JuMP.set_upper_bound(output, 4.5)

    @objective(m, Min, (output - pmax_value) * (output - pmax_value))

    solve_model(m)

    return JuMP.value(input[5])

end 