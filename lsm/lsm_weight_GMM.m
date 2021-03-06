function [Ktrain, Ktraintest,mix] = lsm_weight_GMM(datatrain, datatest,R_no,val,nForgetPoints, dt_out, SpikingInput)
% Gaussian mixture algorithms to compute the model distance

if nargin<6 || isempty(dt_out) || dt_out <= 0
    dt_out = 4e-3;
end
if nargin<6
    SpikingInput = 0;
end

rng(42);

n_tr=length(datatrain);
n_te=length(datatest);

X = datatrain{1};
X = X';

if (nargin<3)
    R_no = 25;
end

[N,dim]= size(X);

nInputUnits = dim+1;
nInternalUnits = R_no;
nOutputUnits = dim;

if ~SpikingInput
    inputScalingVect = ones(nInputUnits,1)*2;
    inputShiftVect = zeros(nInputUnits,1)-0.5;
    teacherScalingVect = ones(nOutputUnits,1)*2;
    teacherShiftVect =zeros(nOutputUnits,1)-0.5;
    feedbackScalingVect = ones(nOutputUnits,1)*0;
else
    % ALERT: These settings will not be used when SpikingInput=true
    inputScalingVect    = ones(nInputUnits,1)*0.2; % ALERT: this is import for spiking Wout result.
    inputShiftVect      = zeros(nInputUnits,1);
    teacherScalingVect  = ones(nOutputUnits,1)*100;
    teacherShiftVect    = zeros(nOutputUnits,1);
    feedbackScalingVect = ones(nOutputUnits,1)*0;
end

%%%%%%%%%%%%%%%%%%%%%%%
lsm = generate_lsm(nInputUnits, nInternalUnits, nOutputUnits,...
    'spectralRadius',0.9,'inputScaling',inputScalingVect,'inputShift',inputShiftVect, ...
    'teacherScaling',teacherScalingVect,'teacherShift',teacherShiftVect,'feedbackScaling',feedbackScalingVect, ...
    'type', 'plain_lsm', 'dt_out', dt_out, 'SpikingInput', SpikingInput);
lsm.internalWeights = lsm.spectralRadius * lsm.internalWeights_UnitSR;
if ~SpikingInput
    lsm.methodWeightCompute = 'wiener_hopf';
else
    lsm.methodWeightCompute = 'bonus';
end
%%%%%%%%%%%%%%%%%%%%%%%

%%%% train the LSM
lsm.noiseLevel = 0;
lsm = create_lsm_topology(lsm);

%%
step = 1;

len = N - nForgetPoints - 1;
Wmat = zeros(n_tr,R_no);
statemat = zeros(n_tr,len,R_no);
statemat2 = zeros(n_te,len,R_no);

for i=1:n_tr
    fprintf('.');
    X = datatrain{i}';
    trainInputSequence = [X(1:N-step,:) ones(N-step,1)];
    trainOutputSequence = X(1+step:N,:);
    [trainedLSM,stateCollection] = train_lsm(trainInputSequence, ...
        trainOutputSequence, lsm, nForgetPoints,val);
    %     [predictedTrainOutput] = test_lsm(trainInputSequence, trainedLSM,nForgetPoints);
    %     trainError = compute_error(predictedTrainOutput, trainOutputSequence);
    data = trainedLSM.outputWeights;
    Wmat(i,:) = data(:,1:R_no);
    statemat(i,:,:) = stateCollection(:,1:R_no);
    
    if mod(i,50)==0
        fprintf('\n');
    end
end

Wtemat = zeros(n_te,R_no);

for i=1:n_te
    fprintf('.');
    X = datatest{i}';
    trainInputSequence = [X(1:N-step,:) ones(N-step,1)];
    trainOutputSequence = X(1+step:N,:);
    [trainedLSM,stateCollection] = train_lsm(trainInputSequence, ...
        trainOutputSequence, lsm, nForgetPoints,val);
    data = trainedLSM.outputWeights;
    Wtemat(i,:) = data(:,1:R_no);
    statemat2(i,:,:) = stateCollection(:,1:R_no);
    
    if mod(i,50)==0
        fprintf('\n');
    end
end

%%
state = reshape(statemat,len*n_tr,R_no);
state2 = reshape(statemat2,len*n_te,R_no);

% [bestk,bestpp,bestmu,bestcov] = mixtures4(state,1,25,0,1e-4,2);

% if (nargin<4)
    [bestk,bestpp,bestmu,bestcov] = mixtures5([state(1:10:end,:); state2(1:10:end,:)]',...
        1,25,0,1e-4,0,[],[],0);
    mix.bestk = bestk;
    mix.bestpp = bestpp;
    mix.bestmu = bestmu;
    mix.bestcov = bestcov;
% else
%     bestk = mix.bestk;
%     bestpp = mix.bestpp;
%     bestmu = mix.bestmu;
%     bestcov = mix.bestcov;
% end

% "bestk" is the selected number of components
% "bestpp" is the obtained vector of mixture probabilities
% "bestmu" contains the estimates of the means of the components
%          it has bestk columns by d lines
% "bestcov" contains the estimates of the covariances of the components
%           it is a three-dimensional (three indexes) array
%           such that bestcov(:,:,1) is the d by d covariance of the first
%           component and bestcov(:,:,bestk) is the covariance of the last
%           component

Ktrain=zeros(n_tr,n_tr);
Ktraintest=zeros(n_tr,n_te);

for i = 1:n_tr
    fprintf('.');
    for j=(i+1):n_tr
        W = Wmat(i,:)-Wmat(j,:);
        dist2 = 0;
        for k=1:bestk
            temp = bestpp(k)*(trace(W'*W*bestcov(:,:,k))+ (bestmu(:,k)'*W')*W*bestmu(:,k));
            dist2 = dist2 + temp;
        end
        Ktrain(i,j) = dist2;
    end
    if mod(i,50)==0,
        fprintf('\n');
    end
end

Ktrain = Ktrain+Ktrain';

if n_tr == n_te
    
    for i=1:n_tr
        fprintf('.');
        for j=1:n_te
            W = Wmat(i,:) - Wtemat(j,:);
            dist2 = 0;
            for k=1:bestk
                temp = bestpp(k)*(trace(W'*W*bestcov(:,:,k))+ (bestmu(:,k)'*W')*W*bestmu(:,k));
                dist2 = dist2 + temp;
            end
            Ktraintest(i,j) = dist2;
        end
        if mod(i,50)==0,
            fprintf('\n');
        end
    end
else
    for i=1:n_tr
        fprintf('.');
        for j=1:n_te
            W = Wmat(i,:)-Wtemat(j,:);
            dist2 = 0;
            for k=1:bestk
                temp = bestpp(k)*(trace(W'*W*bestcov(:,:,k))+ (bestmu(:,k)'*W')*W*bestmu(:,k));
                dist2 = dist2 + temp;
            end
            Ktraintest(i,j) = dist2;
        end
        if mod(i,50)==0,
            fprintf('\n');
        end
    end
end

