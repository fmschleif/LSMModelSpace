function [ E ] = spikes2exp ( S, Tsim, dt, tau )
% SPIKES2EXP transfer spike train to exp
%	f(s) = s*exp(-s/tau)/tau
%	
%	See also bonus
%	
%	Author: Junyuan Hong, 2015-05-27, jyhong836@gmail.com

nPoints = floor(Tsim/dt);
E = zeros(nPoints,1);
sl = floor(3*tau/dt);
si = 1:sl;
s = si * dt;
fs = s.*exp(-s/tau)/tau;
% fs = exp(-s/tau)/tau;
% fs = -(s-tau).*exp(-(s-tau)/tau)/tau;
% TODO: �??�?????�??�????���??�??�?���?????�?���??�??�??�?���??�??正确?��?�?dt??��???没�?�??�????????�?��??
idx = ceil(S/dt);
for i=1:length(S)
	E(idx(i)+1:idx(i)+sl) = fs;
end
E = E(1:nPoints);

