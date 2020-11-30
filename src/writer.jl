function write_placement(p::Placement, overlap_percentage; 
    file="./output/result.csv")
    output = [round(overlap_percentage*100, digits=2)] 

    push!(output, p.num_sensors)
    for d in p.distances 
        push!(output, d)
    end 

    writedlm(file, output)
end 