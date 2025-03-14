using Plots            # To use plot
using GaussQuadrature  # To use legendre
using SparseArrays     # To use spzeros


# Approximates the Integral of a given function in the interval [-1:1]
function gauss_quad(f, ngp)

  # Initializes P and W according to the number of Gauss points
  P, W = legendre(ngp)
  sum = 0

  for j in 1:ngp
    sum = sum + W[j] * f(P[j])
  end

  return sum
end


# Initializes the LG matrix
function init_LG_matrix(ne)
  LG = zeros(Int, 2,ne)

    for j in 1:ne
      LG[1,j] = j
      LG[2,j] = j + 1
    end

  return LG
end


# Initializes the EQ vector and the m variable
function init_EQ_vector_and_m(ne)
  # Initializes m and EQ
  m = ne - 1
  EQ = zeros(Int, ne+1)

  # Computes the first element of EQ
  EQ[1] = m + 1

  # Computes the mid elements of EQ
  for i in 1:m+1
    EQ[i+1] = i
  end

  # Computes the last element of EQ
  EQ[ne+1] = m + 1

  return EQ, m
end


# Initializes the K matrix
function init_K_matrix(ne, EQ, LG, alpha, beta, gamma, m)

  # Initializes the Ke matrix
  function init_Ke_matrix(ne, alpha, beta, gamma)
    h = 1 / ne
    Ke = zeros(2,2)

    for a in 1:2
      for b in 1:2
        Ke[a,b] = (alpha * 2 / h) * gauss_quad((qsi) -> d_phi(a, qsi) * d_phi(b, qsi), 2) + (beta * h / 2) * gauss_quad((qsi) -> phi(a, qsi) * phi(b, qsi), 2) + gamma * gauss_quad((qsi) -> d_phi(b, qsi) * phi(a, qsi), 2)
      end
    end

    return Ke
  end

  # Initializes K and Ke matrices
  K = spzeros(m+1,m+1)
  Ke = init_Ke_matrix(ne, alpha, beta, gamma)

  for e in 1:ne
    for a in 1:2
      i = Int(EQ[LG[a, e]])
      for b in 1:2
        j = Int(EQ[LG[b, e]])
        K[i,j] += Ke[a,b]
      end
    end
  end

  # removes the last line and column
  return K[1:m, 1:m]
end


# Initializes the F vector
function init_F_vector(f, ne, EQ, LG, m)

  # Initializes the Fe vector
  function init_Fe_vector(f, ne, e)
    Fe = zeros(2)
    h = 1 / ne

    for a in 1:2
      Fe[a] = (h / 2) * gauss_quad((qsi) -> f(qsi_to_x(qsi, e, h)) *  phi(a, qsi), 5)
    end

    return Fe
  end

  # Initializes the F vector and the variable h
  h = 1 / ne
  F = zeros(m+1)

  for e in 1:ne
    Fe = init_Fe_vector(f, ne, e)
    for a in 1:2
      i = EQ[LG[a,e]]
      F[i] += Fe[a]
    end
  end

  # Removes the last line
  return F[1:m]
end


# Generalizes the phi (base) function
function phi(number, qsi)
  return [((1 - qsi) / 2), ((1 + qsi) / 2)][number]
end


# Generalizes the derivative of the phi (base) function
function d_phi(number, qsi)
  return [(-1 / 2), (1 / 2)][number]
end


# Converts the interval from [x_i-1 , xi+1] to [-1, 1]
function qsi_to_x(qsi, i, h)
  return (h / 2) * (qsi + 1) + 0 + (i - 1)*h
end


# Solves the system given the input data of the strong formulation
function solve_system(ne, alpha, beta, gamma, f, u)
  # Initializes matrices, vectors and variables
  EQ, m = init_EQ_vector_and_m(ne)
  LG    = init_LG_matrix(ne)
  K     = init_K_matrix(ne, EQ, LG, alpha, beta, gamma, m)
  F     = init_F_vector(f, ne, EQ, LG, m)
  return K \ F
end


# Plots the exact and inexact graphs, as well as the absolute and relative errors
function plot_comparison(ne, alpha, beta, gamma, f, u)
  # Initializes variables
  h = 1 / ne
  xs = [h * i for i in 1:ne-1]
  Cs = solve_system(ne, alpha, beta, gamma, f, u)

  # Includes the boundary conditions in both xs and Cs
  ext_xs = [0; xs; 1]
  ext_Cs = [0; Cs; 0]

  # Plots the exact function and our approximation
  plt = plot(u, 0, 1, label = "u(x)", size=(800, 800))
  plot!(plt, ext_xs, ext_Cs, seriestype = :scatter, label = "Approximation", xlabel = "x", ylabel = "Approximation for u(x)", size=(800, 800))

  # Saves the graph
  savefig("1d-stat-approximation-graph.png")
end


# Plots the graph of errors according to the varying of n
function error_analysis(lb, ub)

  # Computes the error according to ne
  function gauss_error(u, cs, ne, EQ, LG)
    sum = 0
    h = 1 / ne

    # Includes 0 so that the EQ-LG will not consider the first and the last phi function
    extended_cs = [cs; 0]

    # Computes the error
    for e in 1:ne
      sum = sum + gauss_quad((qsi) -> (u(qsi_to_x(qsi, e, h)) - (extended_cs[EQ[LG[1,e]]] * phi(1, qsi)) - (extended_cs[EQ[LG[2,e]]] * phi(2, qsi)))^2, 5)
    end

    return sqrt(sum * (h / 2))
  end

  # Initializes the vectors
  errors = zeros(ub - lb + 1)
  nes = [(1 << i) - 1 for i in lb:ub]
  hs = [1 / nes[i - lb + 1] for i in lb:ub]

  # Computes the errors varying according to the variation of h
  for i in lb:ub
    ne = nes[i-lb+1]
    EQ, m = init_EQ_vector_and_m(ne)
    LG = init_LG_matrix(ne)
    Cs = solve_system(ne, alpha, beta, gamma, f, u)
    e = gauss_error(u, Cs, ne, EQ, LG)
    errors[i-lb+1] = e
  end

  # Plots the errors in the graphic in a log scale
  plot(hs, errors, seriestype = :scatter, label = "Error convergence ",
       xlabel = "h", ylabel = "error", size=(800, 800), xscale=:log10, yscale=:log10,
       markercolor = :blue)
  plot!(hs, errors, seriestype = :line, label = "", linewidth = 2, linecolor = :blue)
  plot!(hs, hs.^2, seriestype = :line, label = "h^2", linewidth = 2, linecolor = :red)

  # Saves the graph in a png file
  savefig("1d-stat-errors-convergence.png")
end


# Constants
alpha = 1
beta  = 1
gamma = 1

# Functions
f = (x) -> alpha*pi^2 * sin(pi*x) + beta*sin(pi*x) + gamma*pi*cos(pi*x)
u = (x) -> sin(pi * x)

# Bound limits for analyzing the error convergence
lb = 2
ub = 17

# Number of elements for plotting a comparison graph and displaying the time it took to compute the approximation
ne = 5

# Testing the implementation
plot_comparison(ne, alpha, beta, gamma, f, u)
error_analysis(lb, ub)

