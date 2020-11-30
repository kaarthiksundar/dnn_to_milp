mutable struct TunnelData 
    wp::Vector{Any}
    lw_wp::Vector{Any}
    rw_wp::Vector{Any}
    distances::Vector{Float64}
    c_distances::Vector{Float64}
    num_turns::Int 
    num_segments::Int
    wall_distance::Float64
end 

dist(x1, x2) = sqrt((x2[2]-x1[2])^2 + (x2[1]-x1[1])^2)

mutable struct Placement 
    num_sensors::Int 
    distances::Vector{Any}
    l_positions::Vector{Any}
    r_positions::Vector{Any}
    segment_id::Dict{Int,Int}
    num_sensors_in_segment::Vector{Int}
    los_points::Vector{Any}
end 

