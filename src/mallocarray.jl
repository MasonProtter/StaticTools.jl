
    const PointerOrInitializer = Union{Ptr, UndefInitializer, typeof(Base.zeros)}

    # Definition and constructors:
    """
    ```julia
    MallocArray{T,N} <: DenseArray{T,N} <: AbstractArray{T,N}
    ```
    `N`-dimensional dense heap-allocated array with elements of type `T`.

    Much like `Base.Array`, except (1) backed by memory that is not tracked by
    the Julia garbage collector (is directly allocated with `malloc`) so is
    StaticCompiler-safe, (2) should be `free`d when no longer in use, and
    (3) contiguous slice indexing returns `ArrayView`s rather than copies.

    Indexing a `MallocArray` out of bounds does not throw a `BoundsError`; much
    as if `@inbounds` were enabled, indexing a `MallocArray` incurs a strict
    promise by the programmer that the specified index is inbounds. Breaking
    this promise will result in segfaults or memory corruption.
    """
    struct MallocArray{T,N} <: DensePointerArray{T,N}
        pointer::Ptr{T}
        length::Int
        size::NTuple{N, Int}
    end
    """
    ```julia
    MallocMatrix{T} <: AbstractMatrix{T}
    ```
    Two-dimensional dense heap-allocated array with elements of type `T`.
    As `Base.Matrix` is to `Base.Array`, but with `MallocArray`.
    """
    const MallocMatrix{T} = MallocArray{T,2}
    """
    ```julia
    MallocVector{T} <: AbstractVector{T}
    ```
    Two-dimensional dense heap-allocated array with elements of type `T`.
    As `Base.Vector` is to `Base.Array`, but with `MallocArray`.
    """
    const MallocVector{T} = MallocArray{T,1}


    """
    ```julia
    MallocArray(T, dims) do A
        ...
    end
    ```
    ```julia
    MallocArray{T}(undef, dims)
    MallocArray{T,N}(undef, dims)
    ```
    ```julia
    MallocArray{T}(zeros, dims)
    MallocArray{T,N}(zeros, dims)
    ```
    Construct an uninitialized (`undef`) or zero-initialized (`zeros`)
    `N`-dimensional `MallocArray` containing elements of type `T`.
    `N` can either be supplied explicitly, as in `Array{T,N}(undef, dims)`,
    or be determined by the length or number of `dims`. `dims` may be a tuple or
    a series of integer arguments corresponding to the lengths in each dimension.
    If the rank `N` is supplied explicitly, then it must match the length or
    number of `dims`.

    Here `undef` is the `UndefInitializer` and signals that `malloc` should be
    used to obtain the underlying memory, while `zeros` is the `Base` function
    `zeros` and flags that `calloc` should be used to obtain and zero-initialize
    the underlying memory.

    Attempting to create a `MallocArray` with dimensions larger than can be
    successfully allocated will return an empty `MallocArray` with size 0 in
    all dimensions and pointer null.

    ## Examples
    ```julia
    julia> A = MallocArray{Float64}(undef, 3,3) # implicit N
    3×3 MallocMatrix{Float64}:
     3.10504e231   6.95015e-310   2.12358e-314
     1.73061e-77   6.95015e-310   5.56271e-309
     6.95015e-310  0.0           -1.29074e-231

    julia> free(A)
    0

    julia> A = MallocArray{Float64, 3}(zeros, 2,2,2) # explicit N, zero initialize
    2×2×2 MallocArray{Float64, 3}:
    [:, :, 1] =
     0.0  0.0
     0.0  0.0

    [:, :, 2] =
     0.0  0.0
     0.0  0.0

    julia> free(A)
    0
    ```
    To avoid having to manually `free` allocated memory, it is recommended to
    use the following supported do-block syntax whenever possible, i.e.
    ```julia
    julia> MallocArray(Float64, 2, 2) do A
               A .= 0
               printf(A)
           end
    0.000000e+00    0.000000e+00
    0.000000e+00    0.000000e+00
    0
    ```
    """
    @inline function MallocArray{T,N}(::UndefInitializer, length::Int, dims::Dims{N}) where {T,N}
        @assert Base.allocatedinline(T)
        @assert length == prod(dims)
        nbytes, f = prod_with_overflow((dims..., sizeof(T)))
        (f || nbytes < 0) && return MallocArray{T,N}(Ptr{T}(C_NULL), 0, ntuple(i->0, N))
        p = Ptr{T}(malloc(nbytes))
        p == C_NULL && return MallocArray{T,N}(p, 0, ntuple(i->0, N))
        MallocArray{T,N}(p, length, dims)
    end
    @inline function MallocArray{T,N}(::typeof(Base.zeros), length::Int, dims::Dims{N}) where {T,N}
        @assert Base.allocatedinline(T)
        @assert length == prod(dims)
        nbytes, f = prod_with_overflow((dims..., sizeof(T)))
        (f || nbytes < 0) && return MallocArray{T,N}(Ptr{T}(C_NULL), 0, ntuple(i->0, N))
        p = Ptr{T}(calloc(nbytes))
        p == C_NULL && return MallocArray{T,N}(p, 0, ntuple(i->0, N))
        MallocArray{T,N}(p, length, dims)
    end
    @inline MallocArray{T,N}(x::PointerOrInitializer, dims::Dims{N}) where {T,N} = MallocArray{T,N}(x, prod(dims), dims)
    @inline MallocArray{T}(x::PointerOrInitializer, dims::Dims{N}) where {T,N} = MallocArray{T,N}(x, prod(dims), dims)
    @inline MallocArray{T,N}(x::PointerOrInitializer, dims::Vararg{Int}) where {T,N} = MallocArray{T,N}(x, prod(dims), dims)
    @inline MallocArray{T}(x::PointerOrInitializer, dims::Vararg{Int}) where {T} = MallocArray{T}(x, dims)
    @inline function MallocArray(f::Function, T::Type, dims...)
        M = MallocArray{T}(undef, dims...)
        y = f(M)
        free(M)
        y
    end

    @inline function prod_with_overflow(x)
        p, f = one(eltype(x)), false
        for i ∈ eachindex(x)
            p, fᵢ = Base.Checked.mul_with_overflow(p, x[i])
            f |= fᵢ
        end
        p, f
    end


    """
    ```julia
    MallocArray(data::AbstractArray{T,N})
    ```
    Construct a `MallocArray` of eltype `T` from an existing `AbstractArray`.

    ### Examples
    ```julia
    julia> a = szeros(Int, 5,5)
    5×5 StackMatrix{Int64, 25, (5, 5)}:
     0  0  0  0  0
     0  0  0  0  0
     0  0  0  0  0
     0  0  0  0  0
     0  0  0  0  0

    julia> MallocArray(a)
    5×5 MallocMatrix{Int64}:
     0  0  0  0  0
     0  0  0  0  0
     0  0  0  0  0
     0  0  0  0  0
     0  0  0  0  0
    ```
    """
    @inline MallocArray(x::AbstractArray{T,N}) where {T,N} = copyto!(MallocArray{T,N}(undef, length(x), size(x)), x)


    # Destructor:
    @inline free(a::MallocArray) = free(a.pointer)

    # Indirect constructors
    @inline Base.similar(a::MallocArray{T,N}) where {T,N} = MallocArray{T,N}(undef, size(a))
    @inline Base.similar(a::MallocArray{T}, dims::Dims{N}) where {T,N} = MallocArray{T,N}(undef, dims)
    @inline Base.similar(a::MallocArray, dims::Vararg{Int}) = similar(a, dims)
    @inline Base.similar(a::MallocArray{To,N}, ::Type{T}) where {To,N,T} = MallocArray{T,N}(undef, dims)
    @inline Base.similar(a::MallocArray, ::Type{T}, dims::Dims{N}) where {T,N} = MallocArray{T,N}(undef, dims)
    @inline Base.similar(a::MallocArray, T::Type, dims::Vararg{Int}) = similar(a, T, dims)
    @inline function Base.copy(a::MallocArray{T,N}) where {T,N}
        c = MallocArray{T,N}(undef, size(a))
        copyto!(c, a)
        return c
    end

    # Avoid Base.unsafe_wrap stack overflow
    @inline _unsafe_wrap(::Type{MallocArray{T,N}}, ptr::Ptr, dims::Dims{N}, own::Bool = false) where {T,N} =
        own ?
            error("A MallocArray cannot be owned via `unsafe_wrap`. Set the keyword `own` to be false.") :
            MallocArray{T,N}(ptr, prod(dims), dims)

    # Overload Base.unsafe_wrap
    """
    ```julia
    unsafe_wrap(MallocArray, ptr::Ptr{T}, dims)
    ```
    Create a `MallocArray{T}` wrapping around `ptr`
    """
    @inline Base.unsafe_wrap(::Union{Type{MallocArray},Type{MallocArray{T}},Type{MallocArray{T,N}}}, ptr::Ptr{T}, dims::Dims{N}; own = false) where {T,N} =
        _unsafe_wrap(MallocArray{T,N}, ptr, dims, own)
    @inline Base.unsafe_wrap(::Union{Type{MallocArray},Type{MallocArray{T}},Type{MallocArray{T,1}}}, ptr::Ptr{T}, dim::Integer; own = false) where {T} =
        _unsafe_wrap(MallocArray{T,1}, ptr, (Int(dim),), own)

    # Other custom constructors
    """
    ```julia
    mzeros([T], dims) do A
        ...
    end
    ```
    ```julia
    mzeros([T=Float64,] dims::Tuple)
    mzeros([T=Float64,] dims...)
    ```
    Create a `MallocArray{T}` containing all zeros of type `T`, of size `dims`.
    As `Base.zeros`, but returning a `MallocArray` instead of an `Array`.

    See also `mones`, `mfill`.

    ## Examples
    ```julia
    julia> mzeros(Int32, 2,2)
    2×2 MallocMatrix{Int32}:
     0  0
     0  0
    ```
    To avoid having to manually `free` allocated memory, it is recommended to
    use the following supported do-block syntax whenever possible, i.e.
    ```julia
    julia> mzeros(2,2) do A
               printf(A)
           end
    0.000000e+00    0.000000e+00
    0.000000e+00    0.000000e+00
    0
    ```
    """
    @inline mzeros(dims::Vararg{Int}) = mzeros(dims)
    @inline mzeros(dims::Dims{N}) where {N} = MallocArray{Float64,N}(zeros, dims)
    @inline mzeros(T::Type, dims::Vararg{Int}) = mzeros(T, dims)
    @inline mzeros(::Type{T}, dims::Dims{N}) where {T,N} = MallocArray{T,N}(zeros, dims)
    @inline function mzeros(f::Function, args...)
        M = mzeros(args...)
        y = f(M)
        free(M)
        y
    end

    """
    ```julia
    mones([T=Float64,] dims) do A
        ...
    end
    ```
    ```julia
    mones([T=Float64,] dims::Tuple)
    mones([T=Float64,] dims...)
    ```
    Create a `MallocArray{T}` containing all zeros of type `T`, of size `dims`.
    As `Base.zeros`, but returning a `MallocArray` instead of an `Array`.

    See also `mzeros`, `mfill`.

    ## Examples
    ```julia
    julia> A = mones(Int32, 2,2)
    2×2 MallocMatrix{Int32}:
     1  1
     1  1

    julia> free(A)
    0
    ```
    To avoid having to manually `free` allocated memory, it is recommended to
    use the following supported do-block syntax whenever possible, i.e.
    ```julia
    julia> mones(2,2) do A
               printf(A)
           end
    1.000000e+00    1.000000e+00
    1.000000e+00    1.000000e+00
    0
    ```
    """
    @inline mones(dims...) = mones(Float64, dims...)
    @inline mones(::Type{T}, dims...) where {T} = mfill(one(T), dims...)
    @inline function mones(f::Function, args...)
        M = mones(args...)
        y = f(M)
        free(M)
        y
    end

    """
    ```julia
    meye([T=Float64,] dims) do A
        ...
    end
    ```
    ```julia
    meye([T=Float64,] dim::Int)
    ```
    Create a `MallocArray{T}` containing an identity matrix of type `T`,
    of size `dim` x `dim`.

    ## Examples
    ```julia
    julia> A = meye(Int32, 2)

    2×2 MallocMatrix{Int32}:
     1  0
     0  1

    julia> free(A)
    0
    ```
    To avoid having to manually `free` allocated memory, it is recommended to
    use the following supported do-block syntax whenever possible, i.e.
    ```julia
    julia> meye(2) do A
               printf(A)
           end
    1.000000e+00    0.000000e+00
    0.000000e+00    1.000000e+00
    0
    ```
    """
    @inline meye(dim::Int) = meye(Float64, dim)
    @inline function meye(::Type{T}, dim::Int) where {T}
        A = MallocMatrix{T}(zeros, dim*dim, (dim, dim))
        𝔦 = one(T)
        @inbounds for i=1:dim
            A[i,i] = 𝔦
        end
        return A
    end
    @inline function meye(f::Function, args...)
        M = meye(args...)
        y = f(M)
        free(M)
        y
    end


    """
    ```julia
    mfill(x::T, dims::Tuple)
    mfill(x::T, dims...)
    ```
    Create a `MallocArray{T}` of size `dims`, filled with the value `x`, where `x` is of type `T`.
    As `Base.fill`, but returning a `MallocArray` instead of an `Array`.

    See also `mzeros`, `mones`.

    ## Examples
    ```julia
    julia> mfill(3, 2, 2)
    2×2 MallocMatrix{Int64}:
     3  3
     3  3
    ```
    To avoid having to manually `free` allocated memory, it is recommended to
    use the following supported do-block syntax whenever possible, i.e.
    ```julia
    julia> mfill(1.5, 2,2) do A
               printf(A)
           end
    1.500000e+00    1.500000e+00
    1.500000e+00    1.500000e+00
    0
    ```
    """
    @inline mfill(x, dims::Vararg{Int}) = mfill(x, dims)
    @inline function mfill(x::T, dims::Dims{N}) where {T,N}
        A = MallocArray{T,N}(undef, prod(dims), dims)
        fill!(A, x)
    end
    @inline function mfill(f::Function, args...)
        M = mfill(args...)
        y = f(M)
        free(M)
        y
    end
