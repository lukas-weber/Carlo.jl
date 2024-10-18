using HDF5
using StructEquality

function tmp_hdf5_file(func::Function)
    tmp = tempname(cleanup = true)
    res = try
        h5open(func, tmp, "w")
    finally
        rm(tmp)
    end
    return res
end


function test_checkpointing(obj; type = typeof(obj))
    return tmp_hdf5_file() do file
        group = create_group(file, "test")
        Carlo.write_checkpoint(obj, group)
        obj2 = Carlo.read_checkpoint(type, group)

        return obj == obj2
    end
end
