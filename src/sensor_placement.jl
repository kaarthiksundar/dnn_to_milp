function get_segment_id(distances, cumulative_length)
    segment_id = []
    for i in distances 
        index = findfirst(x -> x >= i, cumulative_length)
        push!(segment_id, index)
    end 
    return segment_id
end 

function rotate_by(x, theta)
    rx = cos(theta) * x[1] - sin(theta) * x[2]
    ry = sin(theta) * x[1] + cos(theta) * x[2]
    return [rx, ry]
end 

function compute_position(distance, fr, to, sensor_distance)
    dx = to[1] - fr[1]
    dy = to[2] - fr[2]
    theta = atan(dy, dx)
    D = sqrt(dx * dx + dy * dy)
    l_s = [distance, sensor_distance]
    r_s = [distance, -sensor_distance]
    l_r = rotate_by(l_s, theta)
    r_r = rotate_by(r_s, theta)
    return (l_r + collect(fr), r_r + collect(fr))
end 


function get_straight_placements(td::TunnelData, drop_distance)
    num_sensors = 2
    distances = Vector()
    l_positions = Vector() 
    r_positions = Vector()
    segment_id = Dict() 
    num_sensors_in_segment = []

    push!(distances, 0.0)

    while true
        last_placement_distance = distances[end]
        if (last_placement_distance + drop_distance > td.c_distances[end])
            break
        end 
        push!(distances, last_placement_distance + drop_distance)
        num_sensors += 2
    end 

    for i in 1:length(distances)
        d = distances[i]
        index = findfirst(x -> d < x, td.c_distances)
        segment_id[i] = index
    end 

    for i in 1:td.num_segments
        count = length([k for (k, v) in segment_id if v == i])
        push!(num_sensors_in_segment, count)
    end 


    for i in 1:length(distances)
        d = distances[i]
        seg_id = segment_id[i]
        (seg_id > 1) && (d -= td.c_distances[seg_id - 1])
        fr = td.wp[seg_id]
        to = td.wp[seg_id + 1]
        l_pos, r_pos = compute_position(d, fr, to, 10.0)
        push!(l_positions, l_pos)
        push!(r_positions, r_pos)
    end 

    return Placement(
        num_sensors, distances, 
        l_positions, r_positions,
        segment_id, num_sensors_in_segment, 
        Vector()
    )
end 

function get_over_placements(td::TunnelData, 
    sp::Placement, drop_distance)::Placement
    num_sensors = 2
    distances = Vector()
    l_positions = Vector() 
    r_positions = Vector()
    segment_id = Dict() 
    num_sensors_in_segment = []

    num_sensors = deepcopy(sp.num_sensors)  
    distances = deepcopy(sp.distances)

    for i in 1:(length(td.c_distances)-1)
        turn_at = td.c_distances[i]
        if !(turn_at in distances)
            push!(distances, turn_at)
            num_sensors += 2 
        end 
    end 

    distances = sort(distances)

    for i in 1:length(distances)
        d = distances[i]
        index = findfirst(x -> d < x, td.c_distances)
        segment_id[i] = index
    end 
    
    for i in 1:td.num_segments
        count = length([k for (k, v) in segment_id if v == i])
        push!(num_sensors_in_segment, count)
    end 

    for i in 1:length(distances)
        d = distances[i]
        seg_id = segment_id[i]
        (seg_id > 1) && (d -= td.c_distances[seg_id - 1])
        fr = td.wp[seg_id]
        to = td.wp[seg_id + 1]
        l_pos, r_pos = compute_position(d, fr, to, 10.0)
        push!(l_positions, l_pos)
        push!(r_positions, r_pos)
    end 

    return Placement(
        num_sensors, distances, 
        l_positions, r_positions,
        segment_id, num_sensors_in_segment, 
        Vector()
    )
end 

function update_placement!(p, td)
    num_sensors = length(p.distances) * 2
    distances = p.distances
    p.l_positions = Vector() 
    p.r_positions = Vector()
    p.segment_id = Dict() 
    p.num_sensors_in_segment = []

    for i in 1:length(distances)
        d = distances[i]
        index = findfirst(x -> d < x, td.c_distances)
        p.segment_id[i] = index
    end 
    
    for i in 1:td.num_segments
        count = length([k for (k, v) in p.segment_id if v == i])
        push!(p.num_sensors_in_segment, count)
    end 

    for i in 1:length(distances)
        d = distances[i]
        seg_id = p.segment_id[i]
        (seg_id > 1) && (d -= td.c_distances[seg_id - 1])
        fr = td.wp[seg_id]
        to = td.wp[seg_id + 1]
        l_pos, r_pos = compute_position(d, fr, to, 10.0)
        push!(p.l_positions, l_pos)
        push!(p.r_positions, r_pos)
    end 
end 

function compute_last_sensor(tunnel_data, placement, segment_id)
    distances = [] 
    sensor_ids = []
    for i in 1:Int(placement.num_sensors/2)
        d = placement.distances[i]
        id = findfirst(x -> x > d, tunnel_data.c_distances)
        if (id == segment_id)  
            push!(distances, d)
            push!(sensor_ids, i)
        end 
    end 
    max_element = findmax(distances)
    return max_element[1], sensor_ids[max_element[2]]
end 

function get_segment_ids(td::TunnelData, segment_id, 
    fr::Float64, to_turn::Float64, drop_distance)

    segment_ids = []
    additional_distance = drop_distance - to_turn
    for i in (segment_id+1):td.num_segments
        if (td.c_distances[i] > drop_distance)
            push!(segment_ids, i)
            break 
        else 
            push!(segment_ids, i)
        end
    end 
    return segment_ids
end 

function get_los_point(s_l, s_r, w_l, w_r, seg_fr, seg_to)

    r_ray = (w_r - s_r)./dist(w_l - s_l, zeros(2))
    l_ray = (w_l - s_l)./dist(w_l - s_l, zeros(2))

    m_r = JuMP.Model()
    m_l = JuMP.Model()

    @variable(m_r, mu_r, lower_bound = 0.0)
    @variable(m_r, 0.0 <= lambda_r <= 1.0)

    @variable(m_l, mu_l, lower_bound = 0.0)
    @variable(m_l, 0.0 <= lambda_l <= 1.0)

    @constraint(m_r, s_r + mu_r * r_ray .== 
        lambda_r * seg_fr + (1-lambda_r) * seg_to)
    @constraint(m_l, s_l + mu_l * l_ray .== 
        lambda_l * seg_fr + (1-lambda_l) * seg_to)

        
    set_optimizer(m_r, CPLEX.Optimizer)
    set_silent(m_r)
    set_optimizer(m_l, CPLEX.Optimizer)
    set_silent(m_l)

    optimize!(m_l)
    optimize!(m_r)

    p_l = [NaN, NaN]
    d_l = NaN
    p_r = [NaN, NaN]
    d_r = NaN

    if (termination_status(m_l) != MOI.INFEASIBLE)
        lambda = JuMP.value(lambda_l) 
        p_l = lambda * seg_fr + (1-lambda) * seg_to
        d_l = dist(p_l, seg_fr)
    end 
    if (termination_status(m_r) != MOI.INFEASIBLE)
        lambda = JuMP.value(lambda_r) 
        p_r = lambda * seg_fr + (1-lambda) * seg_to
        d_r = dist(p_r, seg_fr)
    end 

    (isnan(d_r) && isnan(d_l)) && (return nothing)
    (isnan(d_r)) && (return p_l)
    (isnan(d_l)) && (return p_r) 
    (d_r < d_l) && (return p_r)
    (d_r > d_l) && (return p_l)

end 

function get_optimal_placements(td::TunnelData, 
    sp::Placement, drop_distance)::Placement

    op = deepcopy(sp)

    for i in 1:(td.num_segments-1)
        lw_wp = td.lw_wp[i+1]
        rw_wp = td.rw_wp[i+1]
        prev_sensor_distance, prev_sensor_id = compute_last_sensor(td, op, i)
        distance_to_turn = td.c_distances[i] - prev_sensor_distance
        (prev_sensor_id * 2 == op.num_sensors) && (break)
        next_sensor_distance = op.distances[prev_sensor_id + 1]
        next_sensor_id = prev_sensor_id + 1
        prev_sensor_l_position = op.l_positions[prev_sensor_id]
        prev_sensor_r_position = op.r_positions[prev_sensor_id]
        inter_sensor_distance = drop_distance
        segments_to_consider = get_segment_ids(
            td, i, prev_sensor_distance, distance_to_turn, drop_distance)
        for s in segments_to_consider
            fr = td.wp[s]
            to = td.wp[s+1]
            point = get_los_point(prev_sensor_l_position,
                prev_sensor_r_position, 
                lw_wp, rw_wp, fr, to)
            (isa(point, Nothing)) && (continue)
            d = dist(point, fr)
            point_distance = td.c_distances[s-1] + d 
            push!(op.los_points, point)
            (point_distance > next_sensor_distance) && (continue)
            offset = next_sensor_distance - point_distance
            for id in next_sensor_id:Int(op.num_sensors/2)
                op.distances[id] -= offset
            end 
            update_placement!(op, td)
        end 
    end 

    while true
        last_placement_distance = op.distances[end]
        if (last_placement_distance + drop_distance > td.c_distances[end])
            break
        end 
        push!(op.distances, last_placement_distance + drop_distance)
        op.num_sensors += 2
    end 

    update_placement!(op, td)

    return op
    
end

