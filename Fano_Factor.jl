using Plots
Plots.scalefontsizes(1.2)
#set parameters
l=2 #lambda
d=1
EK=100 #expected value of K
c=1.2 #coefficient of variation

#mu as a function of mean copy number y
u(y) = l * (EK / (d * y)) - l

#Fano factor as a function of mean copy number y (for Telegraph model-instrinsic noise)
Fano(y)= 1 - ((l * EK) / (d * (l + u(y)))) + ((l + d)*EK)/ (d * (l + u(y) + d))
plot(Fano,0, EK/d, line=:dash, xscale=:log10, color=:red, xlabel="Mean expression level", ylabel="Fano Factor", legend=:topleft, label="Intrinsic noise", dpi=200)


#Fano factor as function of mean copy number y (Extrinsic noise with coefficient of variation c)
Fano_extrinsic(y)= 1 - (l/(d*(l + u(y)))) *  EK + ((l + d) * EK)/(d *(l + u(y) + d))  + (l + d )/(d * (l + u(y) + d)) * (c^2)
plot!(Fano_extrinsic, 0, EK/d, xscale=:log10, color=:gray,label="Extrinsic noise c = 1.2")
Plots.pdf("Universalnoise")


#coefficient of variation squared as a function of mean copy number y (Extrinsic noise)
Noisesqrd_extrinsic(y)= Fano_extrinsic(y) * (1 / y)

#coeff. of var. sqrd as a function of mean copy number (Telegraph)
Noisesqrd(y)= Fano(y) * (1/ y)
plot(Noisesqrd, 0, EK/d,line=:dash,color=:red, xscale=:log10, yscale=:log10, xlabel="Mean expression level", ylabel="Squared coefficient of variation", label="Intrinsic noise", dpi=200)
plot!(Noisesqrd_extrinsic, 0, EK/d, color=:gray, xscale=:log10, yscale=:log10, xlabel="Mean expression level", ylabel="Squared coefficient of variation", label="Extrinsic noise c = 1.2", dpi=200)
Plots.pdf("Squarednoise")
