using DataStructures
using Dates
using PyCall

import Base.convert


cfgrib = pyimport("cfgrib")


function python_cfgrib_data(cfgrib_ds::PyObject, data_variable::String)
    python_shape = cfgrib_ds.get(data_variable).shape
    values = cfgrib_ds.get(data_variable).values
    
    @assert python_shape == size(values)
    
    return values
end

function python_cfgrib_data(path::String, data_variable::String)
    cfgrib_ds = cfgrib.open_dataset(path)

    return python_cfgrib_data(cfgrib_ds, data_variable)
end


function convert(::Type{DateTime}, np_datetime::PyObject)
    """Converts python numpy `datetime64[ns]` to Julia `DateTime`
    """
    data = np_datetime.tolist()

    epoch_start = Dates.datetime2epochms(DateTime("1970-01-01T00:00:00"))
    data = [Dates.epochms2datetime(d*1e-6 + epoch_start) for d in data]

    return data
end

function convert(::Type{Nanosecond}, np_datetime::PyObject)
    """Converts python numpy `timedelta64[ns]` to Julia `Dates.Nanosecond`
    """
    data = np_datetime.tolist()
    
    data = [Dates.Nanosecond(d) for d in data]
    
    return data
end

function convert(::Type{Dates.AbstractDateTime}, np_datetime::PyObject)
    """Dispatches PyObject Date conversion to either `DateTime` or `Nanosecond`
    based on the `dtype` value of the `PyObject`
    """
    @assert np_datetime.dtype.str in ("<M8[ns]", "<m8[ns]")
    
    if np_datetime.dtype.str == "<M8[ns]" #  M8 is for times from epoch
        return convert(DateTime, np_datetime)
    elseif np_datetime.dtype.str == "<m8[ns]" #  m8 is for time delta
        return convert(Nanosecond, np_datetime)
    end
end

function python_cfgrib_coords(cfgrib_ds::PyObject, data_variable::String)
    coordinates = OrderedDict()
    for (name, value) in cfgrib_ds.coords.items()
        coord_values = value.values
        if typeof(coord_values) == PyObject
            #  If automatic conversion failed it's (probably) a numpy
            #  datetime64[ns] or timedelta[ns] value
            coord_values = convert(Dates.AbstractDateTime, coord_values)
        end
        coordinates[name] = coord_values
    end

    return coordinates
end

function python_cfgrib_coords(path::String, data_variable::String)
    cfgrib_ds = cfgrib.open_dataset(path)
    return python_cfgrib_coords(cfgrib_ds, data_variable)
end


python_cfgrib_metadata(cfgrib_ds::PyObject, data_variable::String) = cfgrib_ds.get(data_variable).attrs

function python_cfgrib_metadata(path::String, data_variable::String)
    cfgrib_ds = cfgrib.open_dataset(path)
    
    return OrderedDict(python_cfgrib_metadata(cfgrib_ds, data_variable))
end


struct CFGRIBData
    data::Array
    coords::OrderedDict
    meta::OrderedDict
end

function python_cfgrib_load(path::String, data_variable::String)
    cfgrib_ds = cfgrib.open_dataset(path)
    
    coords = python_cfgrib_coords(cfgrib_ds, data_variable)
    data   = python_cfgrib_data(cfgrib_ds, data_variable)
    meta   = python_cfgrib_metadata(cfgrib_ds, data_variable)
    
    return CFGRIBData(data, coords, meta)
end

function convert(::CFGRIBData, cfgrib_ds::PyObject)
    coords = python_cfgrib_coords(cfgrib_ds, data_variable)
    data   = python_cfgrib_data(cfgrib_ds, data_variable)
    meta   = python_cfgrib_metadata(cfgrib_ds, data_variable)
    
    return CFGRIBData(data, coords, meta)
end