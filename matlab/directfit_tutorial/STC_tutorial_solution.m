% Spike triggered-covariance.  In this exercise, we will generate
% model neural response from a complex visual cell in response to 
% natural movie and then use the spike-triggered
% covariance method to attempt to recover this tuning.  We will
% also compare STA to the estimation of the second-order filters
%% Preliminary stuff: get the directory we're in
% and add the proper subdirectories to the path
cpath = which('directfit_tutorial');
[rootDir, name, ext] = fileparts(cpath);
spath = fullfile(rootDir, 'strflab');
addpath(genpath(spath));
dfpath = fullfile(rootDir, 'direct_fit');
addpath(dfpath);
vpath = fullfile(rootDir, 'validation');
addpath(vpath);
ppath = fullfile(rootDir, 'preprocessing');
addpath(ppath);
dataDir = fullfile(rootDir, '..', 'data'); %contains stim/response pairs
stimsDir = fullfile(dataDir, 'all_stims'); %contains the .wav files

%% load a 20x20x20000 natural movie but use a 10x10 path and the first 1500 time points
load (strcat(dataDir,'/mov.mat'));
% let's only take a part of it 
tlength = 15000;
rawStim = single(mov(1:10,1:10,1:tlength));  % single converts to single precision
clear mov;

% We can also generate white noise use:
% rawStim = single(randn([10 10 15000]));

%% Let's create the receptive field of a complex cell using make3dgabor
gparams = [.5 .5 0 3.5 0 .15 .3 0]';
[gabor, gabor90] = make3dgabor([10 10 1], gparams);


% Exercise 1. Plot on figure 1 the Gabor filter and its 90 degree phase-shifted
% complement.  You can copy and past the code from direct_fit tutorial
figure(1);
subplot(2,1,1);
imagesc(gabor);
colormap('gray');
title('Gabor Filter');
axis square;
subplot(2,1,2);
imagesc(gabor90);
colormap('gray');
title('Gabor Filter 90');
axis square;

%% We are now going to make the response of a complex cell using the convolution
% function dotdelay.  The complex response is obtained by the energy model.

% First we need to reshape the gabor patch and the stimulus to a vector
gabor = reshape(gabor, [10*10 1]);
gabor90 = reshape(gabor90, [10*10 1]);
rawStim = reshape(rawStim, [10*10 tlength]);

% Now we convolve filter and stimulus to get responses of two simple-cells
resp0 = dotdelay(gabor, rawStim);
resp90 = dotdelay(gabor90, rawStim);

% The energy model to get response of complex cell
resp = sqrt(resp0.^2 + resp90.^2);

% Exercise 2.
% Plot the resp of the two simple cells and the complex cell on figure(2).
% Use different color lines and zoom in on the firt 200 points
figure(2);
plot(resp0(1:200), 'b');
hold on;
plot(resp90(1:200), 'r');
plot(resp(1:200), 'k', 'lineWidth', 2);
hold off;


%% Generate spikes from response simply by setting a spiking threshold
maxval = max(resp);
resp(resp<.4*maxval)=0;
resp(resp>0)=1;

% Find time indicies of spikes
respidx = find(resp==1);

% Exercise 3.
% Plot spikes on figure 2 as bold tick marks
figure(2);
hold on;
for it=1:length(respidx)
    if (respidx(it) > 200 )
        break;
    end
    plot([respidx(it) respidx(it)], [0 maxval/2], 'k', 'lineWidth', 3);
end
    
%% We are now going to obtain the spike-triggered average.
% Exercise 4.  Obtain a matrix of all the spike triggered stimulus events: STstim
% Calculate the STA and the normalized STA (as in the direct fit tutorial).  
% On figure 3 display both the STA and the correcltly normalized STA. What do you see?  Why? 
% On figure 4 display 100 (a 10x10 grid) of sample stimulus events that led to spikes

% All Stimulus events corresponding to a spike
STstim = rawStim(:,respidx);
% Calculate the spike triggered average - which is the same as the stimulus
% response cross-correlation
STA = sum(STstim,2)./tlength;

% Stimulus auto-correlation
STS = rawStim*rawStim'./tlength;

myfilter = STS\STA;

% Display the STA
figure(3);
subplot(1,2,1);
imagesc(reshape(STA, [10 10])); axis image; axis off; colormap gray;
title('STA');
subplot(1,2,2);
imagesc(reshape(myfilter, [10 10])); axis image; axis off; colormap gray;
title('STRF');

% Display some example of stimuli that led to spikes
figure(4);
for i=1:100
    subplot(10,10,i);
    imagesc(reshape(STstim(:,i), [10 10]));
    axis image; axis off; colormap gray;
end
% The spike-triggered average is very noisy because it averages stimuli
% that are very different from each other

%% We are now going to calculate the covariance matrix of the spike-triggered stimuli

% Exercise 5.  Calculate the Spike Triggered Covariance matrix (call it
% STC) and display its first two eigenvectors.  We have calculated
% covariance matrix in the direct fit tutorial - here you will want to
% first subtract the STA from the spike triggered stimuli and then
% calculate use matrix multiplication to get the average of the cross-products.
% You can use svd() or eig() command in matlab to get the eigen vectors
% (see the direct fit tutorial).
% In figure(5) plot the first two eigenvectors and the original gabor
% filters for comparison.  What do you see?

% First we subtract the STA from the spike trigged stimuli
STstim2 = bsxfun(@minus, STstim, STA);      % the bsxfun repeats the operation for each column
% Then, we calculate covariance matrix of spike triggered stimuli
STC = STstim2*STstim2'./length(respidx);
% Next we get the eigenvectors of the STC (here again using svd) 
[u,s,v] = svd(STC);

% Plot showing STA, Filters, and first 2 eigenvectors of STC matrix
figure(5);
subplot(2,2,1);
imagesc(reshape(gabor, [10 10])); axis image; axis off; colormap gray;
subplot(2,2,2);
imagesc(reshape(gabor90, [10 10])); axis image; axis off; colormap gray;
title('Original Gabor Filters');
subplot(2,2,3);
imagesc(reshape(u(:,1), [10 10])); axis image; axis off; colormap gray;
subplot(2,2,4);
imagesc(reshape(u(:,2), [10 10])); axis image; axis off; colormap gray;
title('Eigen Vects of STC');

% The spike-triggered covariance eigenvectors have signal and show the
% 90 degree phase-shift but they also have greater spread than the original
% filters.

%% We will now repeat the STC as a regression to show that it is equal to
% calculating the second order terms in a Volterra expansion.

% Subtract STA (first order term) from stimuli
rawStim2 = bsxfun(@minus, rawStim, myfilter);

% Make an empty matrix for the second order terms at every frame
secondStim = zeros([tlength 100 100], 'single');

% Calculate the second order terms at each time point.  Since the image has
% 100 (10x10) values, there are now 100x100 or 100000 second order terms.

for ii = 1:tlength
    secondStim(ii,:,:) = rawStim2(:,ii)*rawStim2(:,ii)';
end

% Reshape second order terms 
secondStim = reshape(secondStim, [tlength 10000]);

% Calculate cross-correlation between the second order stimulus products and the response
STR = (secondStim'*resp)./tlength;

% Exercise 6.  Show that the STC matrix is just the uncorrected regression 
% for the second order stimulus products, i.e. the cross-correlation 
% between the stimulus and the second order stimulus product, STR.  Do do
% so just replot the eigenvectors of STR (after reshaping) and display
% these on figure 6.

STC2 = reshape(STR, [100 100]);

[u2,s2,v2] = svd(STC2);

figure(6);
subplot(2,2,1);
imagesc(reshape(gabor, [10 10])); axis image; axis off; colormap gray;
subplot(2,2,2);
imagesc(reshape(gabor90, [10 10])); axis image; axis off; colormap gray;
title('Original Filters');
subplot(2,2,3);
imagesc(reshape(u2(:,1), [10 10])); axis image; axis off; colormap gray;
subplot(2,2,4);
imagesc(reshape(u2(:,2), [10 10])); axis image; axis off; colormap gray;
title('Eigen vectors for 2nd Order terms');

%% Can we do the actual (i.e. correct) regression? To do so, you will
% need to calculate the stimulus covariance for the second order terms
% that covariance is 10000x10000! 100 dimensions --> 10000 second order
% terms --> 100,000,000 cross-products for the second order terms...
% For white noise, this covariance is approximately the
% identity matrix so this can be ignored. But for natural stimuli
% this may be too large for you computer !!!!

% calulate covariance of second order terms after making some space...

STS = secondStim'*secondStim./tlength;  

% I get an out of memory message on my computer.  Does it work for you?
% If so you could then do:

% secondorderfilter = STS\STR;
% 
% % Or use ridge regression as we did in the direct_fit tutorial
% STC4 = reshape(secondorderfilter, 100, 100);
% [u4,s4,v4] = svd(STC4);
% 
% figure(8);
% subplot(2,2,1);
% imagesc(reshape(gabor, [10 10])); axis image; axis off; colormap gray;
% subplot(2,2,2);
% imagesc(reshape(gabor90, [10 10])); axis image; axis off; colormap gray;
% title('Original Filters');
% subplot(2,2,3);
% imagesc(reshape(u4(:,1), [10 10])); axis image; axis off; colormap gray;
% subplot(2,2,4);
% imagesc(reshape(u4(:,2), [10 10])); axis image; axis off; colormap gray;
% title('Eigenvectors of Second Order Regression');

%% When the stimulus space is too large (or in this case the stimulus
% space for second order terms) one can use the gradient descent
% methods.  We are now going to illustrate how to do this with strflab
% using the scaled conjugate descent method. 

%% First set up strlab
global globDat

strf = linInit(10000, [0]);  % Linear model - 10000 spatial dimensions - no delays
strf.b1 = mean(resp);        % Set bias term to the mean of the response
strfData(secondStim, resp)      % Load up the data - note that the stimulus is the second order terms

% These are the options for training
options = trnSCG;             % Scaled conjugate
options.display = 1;          % Display results at each iteration
options.maxIter = 300;        

trainingIdx = [1:globDat.nSample];  % Train on the entire data

%% Now solve for the STRF

strfTrained = strfOpt(strf, trainingIdx, options);

% Here is normalized STC matrix solved by strflab
STC3 = strfTrained.w1;
STC3 = reshape(STC3, [100 100]);


% Exercise 7.  Plot the eigenvectors of STC3 and compare to the original
% filter.  Did the normalization work?

[u3,s3,v3] = svd(STC3);

figure(7);
subplot(2,2,1);
imagesc(reshape(gabor, [10 10])); axis image; axis off; colormap gray;
subplot(2,2,2);
imagesc(reshape(gabor90, [10 10])); axis image; axis off; colormap gray;
title('Original Filters');
subplot(2,2,3);
imagesc(reshape(u3(:,1), [10 10])); axis image; axis off; colormap gray;
subplot(2,2,4);
imagesc(reshape(u3(:,2), [10 10])); axis image; axis off; colormap gray;
title('Eigenvectors of Second Order Regression');

% We are finally recovering the correctly normalized second order terms.
