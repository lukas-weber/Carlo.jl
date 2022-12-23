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


function test_checkpointing(obj)
    return tmp_hdf5_file() do file
        group = create_group(file, "test")
        LoadLeveller.write_checkpoint(obj, group)
        obj2 = LoadLeveller.read_checkpoint(typeof(obj), group)

        return obj == obj2
    end
end
