# Collection of functions used for parameter inference

"""
Function to load in the experimental data, filtering out missings/NaNs and
applying upper cut-off in terms of standard deviations from the mean.
"""
function load_data(File::String, Folder::String, cutOff::Number=5.0)

	rnaData = CSV.read(Folder*File*".csv", datarow=1)[1]
	rnaData = collect(Missings.replace(rnaData, NaN))
	filter!(x -> !isnan(x), rnaData)

	nMax = maximum(round.(rnaData))
	for ii=1:nMax
		global fltData = filter(x -> x<nMax-ii, rnaData)
		# if maximum(fltData)<cutOff*mean(fltData)
		if maximum(fltData)<mean(fltData)+cutOff*std(fltData)
			break
		end
	end

	return fltData

end


"""
Function to evaluate the log-likelihood of the data, given the standard model
with a particular set of parameters.
"""
function log_likelihood(parameters, data)
    
    Nmax = Integer(round(maximum(data)))    # Maximum value in the data
    # P = solvemaster(parameters,Nmax+1)
    P = solvemaster(parameters)
    N = length(P)    # P runs from zero to N-1
    countVec = collect(0:max(N,Nmax))
    Pfull = zeros(Float64, size(countVec))
    Pfull[1:N] = P
    
    idx = Integer.(round.(data)) .+ 1
    filter!(x -> x>0, idx)
    lVec = Pfull[idx]
    
    return sum(log.(lVec))
    
end


"""
Function to evaluate the log-likelihood of the data, given the compound model
with a particular set of parameters.
"""
function log_likelihood_compound(baseParams, distParams, distFunc, idx, data; lTheta::Integer=100, cdfMax::AbstractFloat=0.98)
    
    Nmax = Integer(round(maximum(data)))    # Maximum value in the data
    P = solvecompound(baseParams, distParams, distFunc, idx; N=Nmax)
    L = length(P)
    N = max(L,Nmax)    # P runs from zero to N-1
    countVec = collect(0:N)
    Pfull = [P...;eps(Float64)*ones(Float64,N-L+1)]
    
    indcs = Integer.(round.(data)) .+ 1
    filter!(x -> x>0, indcs)
    lVec = Pfull[indcs]
    
    return sum(log.(lVec))
    
end


"""
Function to perform the MCMC metropolis algorithm.
"""
function mcmc_metropolis(x0::AbstractArray, logPfunc::Function, Lchain::Integer;
                         propVar::AbstractFloat=0.1, burn::Integer=500,
                         step::Integer=500, printFreq::Integer=10000,
                         prior=:none, verbose=true)
    
	if length(size(x0)) > 1 # restart from old chain
        if verbose; println("Restarting from old chain"); end
		xOld = x0[end,:]
		n = length(xOld)
	else
	    xOld = x0
	    n = length(x0)
	end
    chain = zeros(Float64, Lchain,n)
    chain[1,:] = xOld
    acc = 0
    
    if prior == :none
    	logpOld = logPfunc(xOld)
    else
        logpOld = logPfunc(xOld)
        for  (ip,prr) in enumerate(prior)
        	logpOld += log(pdf(prr,xOld[ip]))
        end
    end
    
    for ii=2:Lchain
        proposal = MvNormal(propVar.*sqrt.(xOld))
        xNew = xOld + rand(proposal)
        if prior == :none
	    	logpNew = logPfunc(xNew)
	    else
	        logpNew = 0.0
	        for  (ip,prr) in enumerate(prior)
	        	logpNew += log(pdf(prr,xNew[ip]))
	        end
	        if !isinf(logpNew); logpNew += logPfunc(xNew); end
	    end
        a = exp(logpNew - logpOld)

        if rand(1)[1] < a
            xOld = xNew
            logpOld = logpNew
            acc += 1
        end
        chain[ii,:] = xOld
        
        if ii % printFreq == 0
            if verbose
                Printf.@printf("Completed iteration %i out of %i. \n", ii,Lchain)
            end
        end
    end
    
    if verbose
        Printf.@printf("Acceptance ratio of %.2f (%i out of %i).\n", acc/Lchain,acc,Lchain)
    end

	if length(size(x0)) > 1
		chainRed = [x0; chain[step:step:end,:]] # Append new chain to old
	else
		chainRed = chain[burn:step:end,:]
	end
	return chainRed
    
end


"""
Function to perform the MCMC metropolis algorithm in parallel using multithreading.
"""
function mcmc_metropolis_par(x0::AbstractArray, logPfunc::Function, Lchain::Integer;
                         prior=:none, propVar::AbstractFloat=0.1)
    
    nChains = Threads.nthreads()
    
    r = let m = Random.MersenneTwister(1)
        [m; accumulate(Future.randjump, fill(big(10)^20, nChains-1), init=m)]
    end

	chains = Array{Array{Float64,2},1}(undef,nChains)
	xstarts = Array{Array{Float64,1},1}(undef,nChains)
    if length(size(x0[1])) > 1   # Restart from old chain
        println("Restarting from old chain")
    	for ii=1:nChains
    		xstarts[ii] = x0[ii][end,:]
    	end
    	n = length(x0[1][end,:])
    else
    	for ii=1:nChains
    		xstarts[ii] = x0
    	end
    	n = length(x0)
    end
    println(size(xstarts[1]))

    acc = Threads.Atomic{Int64}(0)

    Threads.@threads for ii=1:nChains
	    chains[ii] = zeros(Float64, Lchain,n)
	    chains[ii][1,:] = xstarts[ii]
	    xOld = xstarts[ii]
	    
	    if prior == :none
			logpOld = logPfunc(xOld)
		else
		    logpOld = logPfunc(xOld)
		    for  (ip,prr) in enumerate(prior)
		    	logpOld += log(pdf(prr,xOld[ip]))
		    end
		end
	    
	    for jj=2:Lchain
            proposal = MvNormal(propVar.*sqrt.(xOld))
	        xNew = xOld + rand(r[Threads.threadid()], proposal)
	        if prior == :none
		    	logpNew = logPfunc(xNew)
		    else
		        logpNew = 0.0
		        for  (ip,prr) in enumerate(prior)
		        	logpNew += log(pdf(prr,xNew[ip]))
		        end
                # Don't evaluate if prior is zero
		        if !isinf(logpNew); logpNew += logPfunc(xNew); end
		    end
	        a = exp(logpNew - logpOld)

	        if rand(r[Threads.threadid()],1)[1] < a
	            xOld = xNew
	            logpOld = logpNew
	            Threads.atomic_add!(acc, 1)
	        end
	        chains[ii][jj,:] = xOld
	    end
	end

    Printf.@printf("Acceptance ratio of %.2f (%i out of %i).\n", acc[]/(Lchain*nChains),acc[],Lchain*nChains)
    
    if length(size(x0[1])) > 1
    	for ii=1:nChains
    		chains[ii] = [x0[ii];chains[ii]] # Append new chain to old
    	end
    end
    return chains
    
end


"""
Function to shrink the MCMC chain, removing the burn-in samples and thinning the remainder.
"""
function chain_reduce(chains; burn::Integer=500, step::Integer=500)

    tmp = Array{Any,1}(undef,4)
	for ii=1:length(chains)
    	tmp[ii] = chains[ii][burn:step:end,:]
    end

    vcat(tmp...)

end