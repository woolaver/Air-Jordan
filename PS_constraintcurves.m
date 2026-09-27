S = S_begin : delta_S : S_end;

for i = 1:length(S)

    S0 = S_i;
    P_i = P_guess
    tol = 0.1;
    converged = false;

    while converged = false
        W = W(S0, P_i);
       % Compute  W / S0
       T_W_new = f(f/S0);
       T_new = T_W_new * W;
       if T_new - T(i) <= tol
           converged =  true
       end
       T(i) = T_new
    end
end