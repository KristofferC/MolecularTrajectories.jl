
export XTC, GroBox
export GroTrajectory

include("XTC_JB.jl")

const xjb = Xtc_JB
const GroBox{V} = Box{V,3,(true,true,true)}

struct XTC{V} <: AbstractTrajectory{Frame{V}}
    xtcjb::xjb.xtcType
    function XTC{V}(filename::String) where V
        stat, xtcjb = xjb.xtc_init(filename)
        new{V}(xtcjb)
    end
end

function Base.iterate(xtc::XTC{V}, state=0) where V
    stat = xjb.read_xtc(xtc.xtcjb)
    if stat == 11 #EOF
        xjb.close_xtc(xtc.xtcjb)
        return nothing
    else
        time = xtc.xtcjb.time[1]
        x = xtc.xtcjb.x
        positions = [
            V(x[1,i], x[2,i], x[3,i]) for i in 1:xtc.xtcjb.natoms[1]
        ]
        bx = xtc.xtcjb.box
        box_a = V(bx[1,1],bx[2,1],bx[3,1])
        box_b = V(bx[1,2],bx[2,2],bx[3,2])
        box_c = V(bx[1,3],bx[2,3],bx[3,3])
        box = GroBox{V}((box_a, box_b, box_c))

        ( Frame{V}(time, box, positions), state+1 )
    end
end

struct GroTrajectory{V} <: AbstractTrajectory{Frame{V}}
    filenames::Vector{String}
    dt::Float64
    function GroTrajectory{V}(
        filenames::String...
        ;
        dt=0.0
    ) where V
        new{V}(filenames, dt)
    end
end

function gro_frame(io::IO, ::Type{V}, time = 0.0) where V
    lines = readlines(io)
    positions = map(@view(lines[3:end-1])) do line
        V(
            parse(Float64, line[21:28]),
            parse(Float64, line[29:36]),
            parse(Float64, line[37:44]),
        )
    end
    sides = V( map(x->parse(Float64, x), split(lines[end]))..., )
    Frame{V}(time, Box(sides), positions)
end

function Base.iterate(gro::GroTrajectory{V}, state=0) where V
    if state+1>length(gro.filenames)
        nothing
    else
        open(gro.filenames[state+1]) do f
            (
                gro_frame(f, V, (state+1)*gro.dt),
                state+1,
            )
        end
    end
end

