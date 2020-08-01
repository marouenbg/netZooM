function RunPUMALIONESSsubset(outtag, alpha, motif_file, exp_file, ppi_file, mir_file, SelectSize, Offset)
% Description:
%             PUMALIONESSsubset can reconstruct user-specified single-sample gene regulatory networks using both transcription factors and microRNAs as regulators of mRNA expression levels.
% Inputs:
%             exp_file  : path to file containing gene expression as a matrix of size (g,g)
%             motif_file: path to file containing the prior TF-gene regulatory network based on TF motifs as a matrix of size (t,g)
%             ppi_file  : path to file containing TF-TF interaction graph as a matrix of size (t,t)
%             outtag    : path to save output PUMA network in .pairs format.
%             mir_file  : path to file containing microRNA file
%             alpha     : learning parameter for the PUMA algorithm
%             SelectSize: number of samples to reconstruct
%             Offset    : first sample to reconstruct
% Author(s):
%             Marieke Kuijjer
% Publications:
%             https://www.ncbi.nlm.nih.gov/pubmed/28506242

    %% Read in Data %%
    disp('Reading in data!')

    % Expression Data
    fid=fopen(exp_file, 'r');
    headings=fgetl(fid);
    NumConditions=length(regexp(headings, '\t'));
    frewind(fid);
    Exp=textscan(fid, ['%s', repmat('%f', 1, NumConditions)], 'delimiter', '\t', 'CommentStyle', '#');
    fclose(fid);
    GeneNames=Exp{1};
    NumGenes=length(GeneNames);
    Exp=cat(2, Exp{2:end});
    % Exp=quantilenorm(Exp); % quantile normalize data

    % Prior Regulatory Network and miR information (PUMA)
    [TF, gene, weight]=textread(motif_file, '%s%s%f');
    if(~isempty(mir_file)) % check miRs in mir_file
        [miR]=textread(mir_file, '%s');
    end

    TFNames=unique(TF);
    NumTFs=length(TFNames);
    [~,i]=ismember(TF, TFNames); % convert regulators to integers
    [~,j]=ismember(gene, GeneNames); % convert genes to integers
    RegNet=zeros(NumTFs, NumGenes);
    RegNet(sub2ind([NumTFs, NumGenes], i, j))=weight; % put weights from motif_file in matrix

    % if mir_file exists (PUMA), check indices of miRs in the PPI data
    if(~isempty(mir_file))
        [~,k]=ismember(miR, TFNames);
            m=(1:NumTFs)';
            [s1,s2] = ndgrid(k,m);
            [t1,t2] = ndgrid(m,k);
    end

    % PPI Data
    TFCoop=eye(NumTFs); % identity matrix of PPI file, or ppi_file
    if(~isempty(ppi_file))
        [TF1,TF2,weight]=textread(ppi_file, '%s%s%f');
        [~,i]=ismember(TF1, TFNames);
        [~,j]=ismember(TF2, TFNames);
        TFCoop(sub2ind([NumTFs, NumTFs], i, j))=weight;
        TFCoop(sub2ind([NumTFs, NumTFs], j, i))=weight;
        % set all edges between regulators present in mirlist and other regulars 0
        if(~isempty(mir_file))
            TFCoop(sub2ind([NumTFs, NumTFs],s1,s2))=zeros(size(k,1), NumTFs);
            TFCoop(sub2ind([NumTFs, NumTFs],t1,t2))=zeros(NumTFs, size(k,1));
        end
        % set diagonal of TFCoop to 1 (self-interactions)
        TFCoop(1:(size(TFCoop,1)+1):end) = 1; % used in both PANDA and PUMA
    end

    NumConditions=size(Exp,2);
    isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
    if isOctave
        GeneCoReg= corrcoef(Exp', 'Mode', 'Pearson', 'rows', 'pairwise');
    else
        GeneCoReg=corr(Exp', 'type', 'pearson', 'rows', 'pairwise');
    end
    %NumUsed=double(~isnan(Exp))*double(~isnan(Exp)'); % optional: determine nr of samples with expression values (not NaN)
    %GeneCoReg=GeneCoReg.*(NumUsed/NumConditions); % optional: normalize the correlation based on NumUsed
    GeneCoReg(1:NumGenes+1:NumGenes^2)=1; % set diagonal to 1
    GeneCoReg(isnan(GeneCoReg))=0; % change NAs to 0

    if(isempty(mir_file)) % run PANDA
        AgNet=PANDA(RegNet, GeneCoReg, TFCoop, alpha);
        AgNet=AgNet(:);
    end
    if(~isempty(mir_file)) % run PUMA
        AgNet=PUMA(RegNet, GeneCoReg, TFCoop, alpha, s1, s2, t1, t2); % s1, s2, t1, t2 are indices of miR interactions in TFCoop
        AgNet=AgNet(:);
    end

    % this code will run LIONESS to generate single-sample networks
    myNumConditions=(Offset+1):(Offset+SelectSize);
    PredNet=zeros(NumTFs*NumGenes, SelectSize);
    for(condcnt=myNumConditions)
        idx=[1:(condcnt-1),(condcnt+1):NumConditions];
        isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
        if isOctave
            GeneCoReg = corrcoef(Exp(:,idx)', 'Mode', 'Pearson', 'rows', 'pairwise');
        else
            GeneCoReg = corr(Exp(:,idx)', 'type', 'pearson', 'rows', 'pairwise');
        end
        %NumUsed=double(~isnan(Exp(:,idx)))*double(~isnan(Exp(:,idx))');  % optional: determine nr of samples with expression values (not NaN)
        %GeneCoReg=GeneCoReg.*(NumUsed/(NumConditions-1)); % optional: normalize the correlation based on NumUsed
        GeneCoReg(1:NumGenes+1:NumGenes^2)=1; % set diagonal to 1
        GeneCoReg(isnan(GeneCoReg))=0; % change NAs to 0
        if(isempty(mir_file)) % run PANDA
            LocNet=PANDA(RegNet, GeneCoReg, TFCoop, alpha);
        end
        if(~isempty(mir_file)) % run PUMA
            LocNet=PUMA(RegNet, GeneCoReg, TFCoop, alpha, s1, s2, t1, t2);
        end
        idPredNet=condcnt-Offset;
        PredNet(:,idPredNet)=NumConditions*(AgNet-LocNet(:))+LocNet(:);
    end


    TF=repmat(TFNames, 1, length(GeneNames));
    gene=repmat(GeneNames', length(TFNames), 1);
    TF=TF(:);
    gene=gene(:);
    RegNet=RegNet(:);

    fid=fopen([outtag, '_FinalNetwork.pairs'], 'wt');
    for(cnt=1:length(TF))
        fprintf(fid, '%s\t%s\t%f\t%f\n', TF{cnt}, gene{cnt}, RegNet(cnt), AgNet(cnt));
    end
    fclose(fid);


    % to save the LIONESS networks in a .mat file
    if isOctave
        save([outtag, '_LIONESSNetworks.mat'], 'PredNet', 'TF', 'gene', 'AgNet', 'RegNet');
    else
        save([outtag, '_LIONESSNetworks.mat'], '-v7.3', 'PredNet', 'TF', 'gene', 'AgNet', 'RegNet');
    end

    % optional: print single-sample edge weights in a .txt file
    %dlmwrite([outtag,'_LIONESSNetworks.txt'], PredNet, '\t');
    
end
