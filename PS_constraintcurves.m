S = S_begin : delta_S : S_end;

for i = 1:length(S)

    S0 = S_i;
    P_i = P_guess;
    tol = 0.1;
    converged = false;

    while converged = false
        W = W(S0, P_i);
       % Compute  W / S0
       P_W_new = f(f/S0);
       P_new = P_W_new * W;
       if P_new - P(i) <= tol
           converged =  true
       end
       P(i) = P_new
    end
end