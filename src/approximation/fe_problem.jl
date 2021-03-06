# fe_problem.jl

"""
An FE_Problem groups all the information of a Fourier extension problem.
This data can be used in a solver to produce an approximation.
"""
abstract FE_Problem{N,T}

for op in [:eltype, :ndims, :numtype]
    @eval $op(p::FE_Problem) = $op(frequency_basis(p))
end


# This type groups the data corresponding to a FE problem.
immutable FE_DiscreteProblem{N,T} <: FE_Problem{N,T}
    domain          ::  AbstractDomain{N}

    op              ::  AbstractOperator
    opt             ::  AbstractOperator

    # The original and extended frequency basis
    fbasis1         ::  FunctionSet{N,T}
    fbasis2         ::  FunctionSet{N,T}
    # The original and extended time basis
    tbasis1         ::  FunctionSet{N,T}
    tbasis2         ::  FunctionSet{N,T}
    # Time domain basis restricted to the domain of the problem
    tbasis_restricted         ::  FunctionSet{N,T}

    # Extension and restriction operators
    f_extension         # from fbasis1 to fbasis2
    f_restriction       # from fbasis2 to fbasis1
    t_extension         # from tbasis_restricted to tbasis2
    t_restriction       # from tbasis2 to tbasis_restricted

    # Transforms from time to frequency domain and back
    transform1          # from tbasis1 to fbasis1
    itransform1         # from fbasis1 to tbasis1
    transform2          # from tbasis2 to fbasis2
    itransform2         # from fbasis2 to tbasis2

    normalization       # transform normalization operator
    invnormalization       # inverse of the transform normalization operator
end

"""
Compute a grid of a larger basis, but restricted to the given domain, using oversampling by the given factor
(approximately) in each dimension.
The result is the tuple (oversampled_grid, larger_basis)
"""
oversampled_grid(set::DomainFrame, args...) =
    oversampled_grid(domain(set), basis(set), args...)


function oversampled_grid(domain, basis::BasisFunctions.FunctionSet, sampling_factor)
    N = ndims(basis)
    n_goal = length(basis) * sampling_factor^N
    grid1 = BasisFunctions.grid(basis)
    grid2 = FrameFun.subgrid(grid1, domain)
    ratio = length(grid2) / length(grid1)
    # Initial guess : This could be way off if the original size was small.
    newsize = ceil(Int,n_goal/ratio)
    n = BasisFunctions.approx_length(basis, newsize)
    large_basis = resize(basis, n)
    grid3 = BasisFunctions.grid(large_basis)
    grid4 = FrameFun.subgrid(grid3, domain)
    # If the number of sampling points is correct, return
    if length(grid4)==n_goal
        return grid4, large_basis
    end
    maxN = newsize
    # 
    while length(grid4)<n_goal
        newsize = 2*newsize
        n = BasisFunctions.approx_length(basis, newsize)
        large_basis = resize(basis, n)
        grid3 = BasisFunctions.grid(large_basis)
        grid4 = FrameFun.subgrid(grid3, domain)
        maxN = newsize
    end
    minN = newsize>>>1
    its = 0
    while (maxN-minN) >1 && its < 40
        midpoint = (minN+maxN) >>> 1
        n = BasisFunctions.approx_length(basis,  midpoint)
        large_basis = resize(basis, n)
        grid3 = BasisFunctions.grid(large_basis)
        grid4 = FrameFun.subgrid(grid3, domain)
        length(grid4)<n_goal ? minN=midpoint : maxN=midpoint
        its += 1
    end
    n = BasisFunctions.approx_length(basis,  maxN)
    large_basis = resize(basis, n)
    grid3 = BasisFunctions.grid(large_basis)
    grid4 = FrameFun.subgrid(grid3, domain) 
    grid4, large_basis
end


function FE_DiscreteProblem(domain, basis, sampling_factor; options...)
    fbasis1 = basis
    rgrid, fbasis2 = oversampled_grid(domain, fbasis1, sampling_factor)
    grid1 = grid(fbasis1)
    grid2 = grid(fbasis2)

    ELT = eltype(fbasis1)
    tbasis1 = DiscreteGridSpace(grid1, ELT)
    tbasis2 = DiscreteGridSpace(grid2, ELT)
    tbasis_restricted = DiscreteGridSpace(rgrid, ELT)

    FE_DiscreteProblem(domain, fbasis1, fbasis2, tbasis1, tbasis2, tbasis_restricted; options...)
end



function FE_DiscreteProblem(domain::AbstractDomain, fbasis1, fbasis2, tbasis1, tbasis2, tbasis_restricted; options...)
    f_extension = extension_operator(fbasis1, fbasis2; options...)
    f_restriction = restriction_operator(fbasis2, fbasis1; options...)

    t_extension = extension_operator(tbasis_restricted, tbasis2; options...)
    t_restriction = restriction_operator(tbasis2, tbasis_restricted; options...)
    transform1 = transform_operator(tbasis1, fbasis1; options...)
    itransform1 = transform_operator(fbasis1, tbasis1; options...)
    transform2 = transform_operator(tbasis2, fbasis2; options...)
    itransform2 = transform_operator(fbasis2, tbasis2; options...)

    # TODO: we also need to incorporate the transform_operator_pre somewhere
    normalization = f_restriction * transform_operator_post(tbasis2, fbasis2; options...) * f_extension
    invnormalization = f_restriction * inv(transform_operator_post(tbasis2, fbasis2; options...)) * f_extension
    
    op  = t_restriction * itransform2 * f_extension
    opt = f_restriction * transform2 * t_extension

    FE_DiscreteProblem(domain, op, opt, fbasis1, fbasis2, tbasis1, tbasis2, tbasis_restricted,
        f_extension, f_restriction, t_extension, t_restriction,
        transform1, itransform1, transform2, itransform2, normalization, invnormalization)
end



domain(p::FE_DiscreteProblem) = p.domain

operator(p::FE_DiscreteProblem) = p.op

operator_transpose(p::FE_DiscreteProblem) = p.opt

normalization(p::FE_DiscreteProblem) = p.normalization
invnormalization(p::FE_DiscreteProblem) = p.invnormalization

frequency_basis(p::FE_DiscreteProblem) = p.fbasis1
frequency_basis_ext(p::FE_DiscreteProblem) = p.fbasis2

time_basis(p::FE_DiscreteProblem) = p.tbasis1
time_basis_ext(p::FE_DiscreteProblem) = p.tbasis2
time_basis_restricted(p::FE_DiscreteProblem) = p.tbasis_restricted


f_extension(p::FE_DiscreteProblem) = p.f_extension
f_restriction(p::FE_DiscreteProblem) = p.f_restriction

t_extension(p::FE_DiscreteProblem) = p.t_extension
t_restriction(p::FE_DiscreteProblem) = p.t_restriction


transform1(p::FE_DiscreteProblem) = p.transform1
itransform1(p::FE_DiscreteProblem) = p.itransform1
transform2(p::FE_DiscreteProblem) = p.transform2
itransform2(p::FE_DiscreteProblem) = p.itransform2


size(p::FE_DiscreteProblem) = size(operator(p))

size(p::FE_DiscreteProblem, j) = size(operator(p), j)

size_ext(p::FE_DiscreteProblem) = size(frequency_basis_ext(p))

length_ext(p::FE_DiscreteProblem) = length(frequency_basis_ext(p))

size_ext(p::FE_DiscreteProblem, j) = size(frequency_basis_ext(p), j)

param_N(p::FE_DiscreteProblem) = length(frequency_basis(p))

param_L(p::FE_DiscreteProblem) = length(time_basis_ext(p))

param_M(p::FE_DiscreteProblem) = length(time_basis_restricted(p))
