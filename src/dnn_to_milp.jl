
using JuMP
using CPLEX 

"""
Layer 1 is the input layer and layer n is the output layer.
Number of nodes in the input layer is the number of inputs.
Numer of nodes in the output layer is the number of outputs. 
``w`` is the dictionary of weights - each edge is associated with a weight. 
``b`` is the dictionary of biases - each node is associated with a bias.
Layer numbering: 1, ... , n. 
Edge numbering: Each edge is associate with three numbers L and (I, J)
where, L is the layer id in {1,..., n}, I (J) is the from (to) node. 
An edge in with layer id L connects nodes in layer (L) to (L+1)
"""

mutable struct EdgeId
    I::Int
    J::Int
end

Base.hash(a::EdgeId, h::UInt) = hash(a.I, hash(a.J, hash(:EdgeId, h)))
Base.isequal(a::EdgeId, b::EdgeId) = isequal(a.I, b.I) && isequal(a.J, b.J) && true
Base.:(==)(a::EdgeId, b::EdgeId) = isequal(a.I, b.I) && isequal(a.J, b.J) && true

function create_edges(num_nodes_i::Int, num_nodes_j::Int)::Vector{Tuple{Int,Int}}
    edges = Vector{Tuple{Int,Int}}()
    nodes_fr = collect(1:num_nodes_i)
    nodes_to = collect(1:num_nodes_j)
    for i in nodes_fr
        for j in nodes_to
            push!(edges, (i, j))
        end
    end
    return edges
end

function create_empty_weights(num_layers::Int, num_nodes_in_layer::Vector{Int})::Dict
    weights = Dict()
    for l = 1:(num_layers-1)
        num_nodes_fr = num_nodes_in_layer[l]
        num_nodes_to = num_nodes_in_layer[l+1]
        weights[l] = Dict()
        edges = create_edges(num_nodes_fr, num_nodes_to)
        for edge in edges
            weights[l][EdgeId(edge[1], edge[2])] = 0.0
        end
    end
    return weights
end

function create_empty_biases(num_layers::Int, num_nodes_in_layer::Vector{Int})::Dict
    biases = Dict()
    for l = 1:num_layers
        biases[l] = Dict()
        for i = 1:num_nodes_in_layer[l]
            biases[l][i] = 0.0
        end
    end
    return biases
end

function get_milp(
    num_layers::Int,
    num_nodes_in_layer::Vector{Int},
    w::Dict,
    b::Dict, 
    input_range, 
    output_range;
    m = JuMP.Model(),
)
    Mp = 1e6
    Mn = 1e6

    var = Dict()
    @assert num_nodes_in_layer[end] == 1
    # one variable for each node in the DNN 
    var[:x] = @variable(m, [l in 1:num_layers, n in 1:num_nodes_in_layer[l]])
    x = var[:x]

    # lower bounds on each x variable for all the intermediate nodes 
    @constraint(m, x_lb[l in 2:(num_layers-1), n in 1:num_nodes_in_layer[l]], x[l, n] >= 0)

    # two variables  for each intermediate node in DNN
    var[:s] = @variable(m, [l in 2:(num_layers-1), n in 1:num_nodes_in_layer[l]], lower_bound=0)
    var[:z] = @variable(m, [l in 2:(num_layers-1), n in 1:num_nodes_in_layer[l]], Bin)

    s = var[:s]
    z = var[:z]

    # input variables 
    var[:input] = @variable(m, [1:num_nodes_in_layer[1]], base_name = "input")
    input = var[:input]

    # output variables 
    var[:output] = @variable(m, base_name = "ouptut")
    output = var[:output]

    # input constraint 
    @constraint(m, input_c[n in 1:num_nodes_in_layer[1]], x[1, n] == 2 * 
        (input[n] - input_range[n][1]) / (input_range[n][2] - input_range[n][1]) - 1
    )

    # output constraint 
    @constraint(m, output_denormalization, output == 0.5 * 
        (x[num_layers, 1] + 1) * (output_range[2] - output_range[1]) + output_range[1]
    )

    # linking constraints 
    @constraint(
        m,
        z1_implies_x0[l in 2:(num_layers-1), n in 1:num_nodes_in_layer[l]],
        x[l, n] <= Mp * (1 - z[l, n])
    )
    @constraint(
        m,
        z0_implies_s0[l in 2:(num_layers-1), n in 1:num_nodes_in_layer[l]],
        s[l, n] <= Mn * z[l, n]
    )

    # layer connections intermediate layers 
    @constraint(
        m,
        layer_connections[l in 2:(num_layers-1), n in 1:num_nodes_in_layer[l]],
        sum(w[l-1][EdgeId(j, n)] * x[l-1, j] for j = 1:num_nodes_in_layer[l-1]) + b[l][n] ==
        x[l, n] - s[l, n]
    )

    # layer connection last layer 
    @constraint(
        m,
        layer_connections_last,
        sum(
            w[num_layers-1][EdgeId(j, 1)] * x[num_layers-1, j]
            for j = 1:num_nodes_in_layer[num_layers-1]
        ) + b[num_layers][1] == x[num_layers, 1]
    )

    return m, var
end

function set_input(m, input, data)
    @constraint(m, [i = 1:length(data)], data[i] == input[i])
    return
end 

function solve_model(m)
    set_optimizer(m, CPLEX.Optimizer)
    optimize!(m)
end 