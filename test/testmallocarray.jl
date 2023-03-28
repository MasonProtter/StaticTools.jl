# Test MallocArray type

    # Test MallocArray constructors
    A = MallocArray{Float64}(undef, 20)
    @test isa(A, MallocArray{Float64})
    @test isa(A, MallocVector{Float64})
    @test length(A) == 20
    @test sizeof(A) == 20*sizeof(Float64)
    @test IndexStyle(A) == IndexLinear()
    @test firstindex(A) == 1
    @test lastindex(A) == 20
    @test stride(A,1) == 1
    @test stride(A,2) == 20
    @test pointer(A) == Base.unsafe_convert(Ptr{Float64}, A)

    # Test mutability and indexing
    A[8] = 5
    @test A[8] === 5.0
    A[8] = 3.1415926735897
    @test A[8] === 3.1415926735897
    A[1:end] = fill(2, 20)
    @test A[10] === 2.0
    A[:] = ones(20)
    @test A[8] === 1.0
    @test A == A[1:end]
    @test A === A[:]
    @test A[1:2] === A[1:2]
    @test A[1:2] != A[1:3]
    @test isa(A[1:2], ArrayView)
    @test (A[3:6])[2:3] === A[4:5]

    # Test equality
    @test A == ones(20)
    @test ones(20) == A
    @test A == A
    B = copy(A)
    @test isa(B, MallocArray)
    @test A == B
    @test A !== B
    C = reshape(A, 5, 4)
    @test isa(C, ArrayView{Float64,2})
    @test size(C) == (5,4)
    A[2] = 7
    @test C[2,1] == 7
    A[7] = 2
    @test C[2,2] == 2
    A[1:end] = 5.0
    @test C[2,2] === 5.0
    A[:] = 0.0
    @test all(C .=== 0.0)
    C = reinterpret(Float16, C)
    @test isa(C, ArrayView{Float16,2})
    @test size(C) == (20,4)
    @test all(C .=== Float16(0))

    # Test special indexing for tuples
    A[:] = 0.
    A[(1,3,5)] = 1,3,5
    @test A[(1,3,5)] === (1.,3.,5.)
    A[:] = 0.
    A[(1,3,5)] = (1.,3.,5.)
    @test A[1:5] == [1,0,3,0,5]

    # Special indexing for 0d arrays
    C = MallocArray{Float64}(undef, ())
    C[] = 1
    @test C[] === 1.0
    C[] = 2.0
    @test C[] === 2.0
    @test free(C) == 0

    # Test other constructors
    C = similar(B)
    @test isa(C, MallocArray{Float64,1})
    @test isa(C[1], Float64)
    @test length(C) == 20
    @test size(C) == (20,)
    @test free(C) == 0

    C = similar(B, 10, 10)
    @test isa(C, MallocArray{Float64,2})
    @test isa(C[1], Float64)
    @test length(C) == 100
    @test size(C) == (10,10)
    @test free(C) == 0

    C = similar(B, Float32, 10)
    @test isa(C, MallocArray{Float32,1})
    @test isa(C[1], Float32)
    @test length(C) == 10
    @test size(C) == (10,)
    @test free(C) == 0

    m = (1:10)*(1:10)'
    C = MallocArray(m)
    @test isa(C, MallocArray{Int64,2})
    @test C == m
    @test free(C) == 0

    # The end
    @test free(A) == 0
    @test free(B) == 0

    # Text constructor in higher dims
    B = MallocMatrix{Float32}(undef, 10, 10)
    @test isa(B, MallocArray{Float32,2})
    @test size(B) == (10,10)
    @test length(B) == 100
    @test stride(B,1) == 1
    @test stride(B,2) == 10
    @test stride(B,3) == 100
    @test B[:,1] === B[:,1]
    @test B[3:7,1] === B[3:7,1]
    @test B[3:7,1] != B[4:7,1]
    @test free(B) == 0

    B = MallocArray{Int64,3}(undef,3,3,3)
    @test isa(B, MallocArray{Int64,3})
    @test size(B) == (3,3,3)
    @test length(B) == 27
    @test stride(B,1) == 1
    @test stride(B,2) == 3
    @test stride(B,3) == 9
    @test stride(B,4) == 27
    @test B[:,1,1] === B[:,1,1]
    @test B[1:2,1,1] === B[1:2,1,1]
    @test B[1:2,1,1] != B[1:3,1,1]
    @test B[:,:,1] === B[:,:,1]
    B[:,2,2] .= 7
    @test B[2,2,2] === 7
    B[:,:,2] .= 5
    @test B[2,2,2] === 5
    @test free(B) == 0

    B = MallocArray{Int64}(undef,2,2,2,2)
    @test isa(B, MallocArray{Int64,4})
    @test size(B) == (2,2,2,2)
    @test length(B) == 16
    @test stride(B,1) == 1
    @test stride(B,2) == 2
    @test stride(B,3) == 4
    @test stride(B,4) == 8
    @test stride(B,5) == 16
    @test B[:,1,1,1] === B[:,1,1,1]
    @test B[1:2,1,1,1] === B[1:2,1,1,1]
    @test B[1:2,1,1,1] != B[1:3,1,1,1]
    @test B[:,:,1,1] === B[:,:,1,1]
    @test B[:,:,:,1] === B[:,:,:,1]
    B[:,2,2,2] .= 7
    @test B[2,2,2,2] === 7
    B[:,:,2,2] .= 5
    @test B[2,2,2,2] === 5
    B[:,:,:,2] .= 3
    @test B[2,2,2,2] === 3
    @test free(B) == 0

## -- test other constructors

    A = MallocArray{Float64,2}(zeros, 11, 10)
    @test A == zeros(11,10)
    @test A[1] === 0.0

    B = mzeros(11,10)
    @test B == zeros(11,10)
    @test B[1] === 0.0

    C = mzeros(Int32, 11,10)
    @test C == zeros(Int32, 11,10)
    @test C[1] === Int32(0)

    D = mfill(Int32(0), 11,10)
    @test D == zeros(Int32, 11,10)
    @test D[1] === Int32(0)

    @test A == B == C == D
    free(A)
    free(B)
    free(C)
    free(D)

## ---

## -- test Base.unsafe_wrap

    ptr = StaticTools.malloc(64)
    A = unsafe_wrap(MallocArray, Ptr{Int8}(ptr), 64)
    A .= 1:64
    @test typeof(A) == MallocArray{Int8, 1}
    @test A == 1:64

    B = unsafe_wrap(MallocArray{Int64}, Ptr{Int64}(ptr), (2,4))
    B[:] .= 1:8
    @test typeof(B) == MallocArray{Int64,2}
    @test B == reshape(1:8, (2,4))

    C = unsafe_wrap(MallocArray{Float64,3}, Ptr{Float64}(ptr), (2,2,2))
    C[:] .= 1.0:1.0:8.0
    @test typeof(C) == MallocArray{Float64,3}
    @test C == reshape(1.0:1.0:8.0, (2,2,2))

    free(A)

## ---

    A = mones(11,10)
    @test A == ones(11,10)
    @test A[1] === 1.0

    B = mones(Int32, 11,10)
    @test B == ones(Int32, 11,10)
    @test B[1] === Int32(1.0)

    @test A == B
    free(A)
    free(B)

    A = meye(10)
    @test A == I(10)
    @test A[5,5] === 1.0

    B = meye(Int32, 10)
    @test B == I(10)
    @test B[5,5] === Int32(1.0)

    @test A == B

    # Iteration
    let n = 0
        for a in A
            n += a
        end
        @test n == 10
    end

    free(A)
    free(B)

## --- test "withmallocarray" pattern

    s = MallocArray(Int64, 2, 2) do A
            A .= 1
            sum(A)
        end
    @test s === 4

    s = mones(2, 2) do A
            sum(A)
        end
    @test s === 4.0

    s = mzeros(2, 2) do A
            sum(A)
        end
    @test s === 0.0

    s = meye(2) do A
            sum(A)
        end
    @test s === 2.0

    s = mfill(3.14, 2, 2) do A
            sum(A)
        end
    @test s === 12.56

## --- RNG conveience functions

    rng = static_rng()

    mrand(rng, 5, 5) do A
        @test isa(A, MallocArray{Float64, 2})
        @test size(A) == (5,5)
        @test all(x -> 0 <= x <= 1, A)
    end

    mrand(rng, Float64, 5, 5) do B
        @test isa(B, MallocArray{Float64, 2})
        @test size(B) == (5,5)
        @test all(x -> 0 <= x <= 1, B)
    end

    rng = MarsagliaPolar()

    mrandn(rng, 5, 5) do A
        @test isa(A, MallocArray{Float64, 2})
        @test size(A) == (5,5)
        @test isapprox(sum(A)/length(A), 0, atol=1)
    end

    mrandn(rng, Float64, 5, 5) do B
        @test isa(B, MallocArray{Float64, 2})
        @test size(B) == (5,5)
        @test isapprox(sum(B)/length(B), 0, atol=1)
    end
