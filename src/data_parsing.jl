function get_data(args)::TunnelData
    case_file = parsed_args["casefile"]
    wall_case_file = parsed_args["wallcasefile"]

    case_data = readdlm(case_file)
    wall_distance = case_data[6]
    wp = []
    for i in 7:2:length(case_data)
        push!(wp, [case_data[i], case_data[i+1]])
        (i+1 == length(case_data)) && (break)
    end 
    distances = []
    c_distances = [] 
    for i in 1:(length(wp)-1)
        push!(distances, dist(wp[i], wp[i+1]))
    end 
    c_distances = [distances[1]] 
    for i in 2:length(distances)
        last = c_distances[end]
        push!(c_distances, last + distances[i])
    end 
    num_turns = length(wp) - 2
    num_segments = length(wp) - 1 

    wall_data = readdlm(wall_case_file, ',')
    lw_wp = []
    rw_wp = [] 
    for i in 1:2:size(wall_data)[1]
        push!(lw_wp, [wall_data[i, 1], wall_data[i+1, 1]])
        push!(rw_wp, [wall_data[i, 2], wall_data[i+1, 2]])
        (i+1 == size(wall_data)[1]) && (break)
    end 

    return TunnelData(wp, lw_wp, rw_wp, 
        distances, c_distances, num_turns, num_segments, wall_distance)

end