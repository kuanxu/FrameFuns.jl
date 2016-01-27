# plots.jl


# One-dimensional plot, just the domain
function plot(f::FrameFun{1}; n=200)
    grid = EquispacedGrid(n,left(domain(f)),right(domain(f)))
    data = convert(Array{Float64},real(f(grid)))
    Main.PyPlot.plot(BasisFunctions.range(grid),data)
    Main.PyPlot.title("Extension (domain)")
end

## # One-dimensional plot, including extension
## function plot_full{1}(f::Fun{1})
    
## end
function plot_expansion(f::FrameFun{1}; n=200, repeats=0)
    grid = EquispacedGrid(n,left(basis(set(f))),right(basis(set(f))))
    data = convert(Array{Float64},real(f(grid)))
    for i=-repeats:repeats
        Main.PyPlot.plot(BasisFunctions.range(grid)+i*(right(grid)-left(grid)),data,linestyle="dashed",color="blue")
    end
    Main.PyPlot.plot(BasisFunctions.range(grid),data,color="blue")
    Main.PyPlot.title("Extension (Full)")
end

function plot_error(f::FrameFun{1}, g::Function; n=200, repeats = 0)
    grid = EquispacedGrid(n,left(basis(set(f))),right(basis(set(f))))
    data = real(f(grid))
    plotdata=convert(Array{Float64},abs(g(BasisFunctions.range(grid))-data))    
    for i=-repeats:repeats
        Main.PyPlot.semilogy(BasisFunctions.range(grid)+i*(right(grid)-left(grid)),plotdata,linestyle="dashed",color="blue")
    end
    Main.PyPlot.semilogy(BasisFunctions.range(grid),plotdata,color="blue")
    Main.PyPlot.ylim([min(minimum(log10(plotdata)),-16),1])
    Main.PyPlot.title("Absolute Error")
end 

function plot_samples(f::FrameFun{1}; gamma=2)
    grid, fbasis2 = oversampled_grid(domain(f), basis(f), gamma)
    x = [grid[i] for i in eachindex(grid)]
    data = convert(Array{Float64},real(f(grid)))
    Main.PyPlot.stem(x,data)
    Main.PyPlot.title("samples")
end 

    
## # Maybe place this in funs.jl?
## function call(f::FrameFun, g::AbstractGrid)
##     result = Array(eltype(f), size(g))
##     call!(f, result, g)
##     result
## end

## function call!{N}(f::FrameFun, result::AbstractArray, g::AbstractGrid{N})
##     x = Array(eltype(f), N)
##     for i in eachindex(g)
##         getindex!(x, g, i)
##         result[i] = call(f, x...)
##     end
## end

## function call!(f::FrameFun, result::AbstractArray, g::AbstractGrid1d)
##     for i in eachindex(g)
##         result[i] = call(f, g[i])
##     end
## end

## function call!(f::FrameFun, result::AbstractArray, x::AbstractArray)
##     @assert size(result) == size(x)
##     for i = 1:length(x)
##         result[i] = call(f, x[i])
##     end
## end

function apply(f::Function, return_type, g::AbstractGrid)
    result = Array(return_type, size(g))
    call!(f, result, g)
    result
end

function call!{N}(f::Function, result::AbstractArray, g::AbstractGrid{N})
    for i in eachindex(g)
        result[i] = f(getindex(g, i)...)
    end
end


function plot_domain(d::AbstractDomain{2}; n=1000)
    B = boundingbox(d)    
    grid = equispaced_aspect_grid(B,n)
    Z = evalgrid(grid, d)
    Main.PyPlot.imshow(Z',interpolation="bicubic",cmap="Blues",extent=(left(B)[1], right(B)[1], left(B)[2], right(B)[2]),aspect="equal",origin="lower")
end


function plot(f::FrameFun{2};n=1000)
    B = boundingbox(domain(set(expansion(f))))
    Tgrid = equispaced_grid(B,n)
    Mgrid=MaskedGrid(Tgrid, domain(set(expansion(f))))
    data = convert(Array{Float64},real(expansion(f)(Mgrid)))
    x=[Mgrid[i][1] for i = 1:length(Mgrid)]
    y=[Mgrid[i][2] for i = 1:length(Mgrid)]
    Main.PyPlot.plot_trisurf(x,y,data)
end

function plot_image(f::FrameFun{2};n=200)
    d =domain(set(expansion(f)))
    B = BBox(left(basis(set(expansion(f)))),right(basis(set(expansion(f)))))
    Tgrid = equispaced_aspect_grid(B,n)
    Mgrid=MaskedGrid(Tgrid, domain(f))
    Z = evalgrid(Tgrid, d)
    data = convert(Array{Float64},real(expansion(f)(Mgrid)))
    vmin = minimum(data)
    vmax = maximum(data)
    data = real(expansion(f)(Tgrid))
    Main.PyPlot.imshow((data./Z)',interpolation="bicubic", extent=(left(B)[1], right(B)[1], left(B)[2], right(B)[2]), vmin=vmin, vmax=vmax, alpha=1.0,origin="lower")
    Main.PyPlot.imshow((data./(1-Z))',interpolation="bicubic", extent=(left(B)[1], right(B)[1], left(B)[2], right(B)[2]), vmin=vmin, vmax=vmax, alpha=1.0,origin="lower")
    Main.PyPlot.colorbar()
end

function plot_error(f::FrameFun{2},g::Function;n=200)
    d =domain(set(expansion(f)))
    B = boundingbox(d)
    Tgrid = equispaced_aspect_grid(B,n)
    Mgrid=MaskedGrid(Tgrid, domain(f))
    Z = evalgrid(Tgrid, d)
    data = real(expansion(f)(Mgrid))
    vmin = minimum(data)
    vmax = maximum(data)
    data = log10(abs(expansion(f)(Tgrid)-apply(g,eltype(f),Tgrid)))
    Main.PyPlot.imshow((data./Z)',interpolation="bicubic", extent=(left(B)[1], right(B)[1], left(B)[2], right(B)[2]) , alpha=1.0,vmin=-16.0,vmax=1.0,aspect="equal",origin="lower")
    Main.PyPlot.imshow((data./(1-Z))',interpolation="bicubic", extent=(left(B)[1], right(B)[1], left(B)[2], right(B)[2]) , alpha=1.0,vmin=-16.0,vmax=1.0,aspect="equal",origin="lower")
    Main.PyPlot.colorbar()
    Main.PyPlot.title("log10 of absolute error")
end

function plot_grid(grid::AbstractGrid2d)
    x=[grid[i][1] for i = 1:length(grid)]
    y=[grid[i][2] for i = 1:length(grid)]
    Main.PyPlot.plot(x,y,linestyle="none",marker="o",color="blue")
    Main.PyPlot.axis("equal")
end

function plot_grid(grid::AbstractGrid3d)
    x=[grid[i][1] for i = 1:length(grid)]
    y=[grid[i][2] for i = 1:length(grid)]
    z=[grid[i][3] for i = 1:length(grid)]
    Main.PyPlot.plot3D(x,y,z,linestyle="none",marker="o",color="blue")
    Main.PyPlot.axis("equal")
end

function plot_grid{TG,GN,ID}(grid::TensorProductGrid{TG,GN,ID,2})
    dom = Cube(left(grid),right(grid))
    Mgrid = MaskedGrid(grid,dom)
    plot_grid(Mgrid)
end

function plot_expansion{N,T}(f::FrameFun{N,T}; n=35)
    Tgrid = TensorProductGrid([EquispacedGrid(n, left(set(expansion(f)),idx), right(set(expansion(f)),idx)) for idx = 1:dim(f)]...)
    data = real(expansion(f)(Tgrid))
    Main.PyPlot.surf(BasisFunctions.range(grid(Tgrid,1)),BasisFunctions.range(grid(Tgrid,2)),data,rstride=1, cstride=1, cmap=Main.PyPlot.ColorMap("coolwarm"),linewidth=0, antialiased=false,vmin=-1.0,vmax=1.0)
end

