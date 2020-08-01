function GeneCoReg = Coexpression(X)
% Description:
%             Compute gene-gene coexpression network for a sample-by-gene matrix X
%             Note that each gene is a column in X
% Inputs:
%             X:         sample-by-gene matrix
% Outputs:
%             GeneCoReg: gene-gene coexpression network
% Author(s):
%             Kimberley Glass
    
	isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
	if isOctave
            GeneCoReg = corrcoef(X, 'Mode', 'Pearson', 'rows', 'pairwise'); 
            % This is corrcoef from the nan package
	else
    		GeneCoReg = corr(X, 'type', 'pearson', 'rows', 'pairwise');
	end
    	
    % Detecting nan in the coexpression network
    % e.g., genes with no expression variation across samples
    if any(any(isnan(GeneCoReg), 2))
       	NumGenes = size(GeneCoReg, 1);
       	GeneCoReg(1:NumGenes+1:NumGenes^2) = 1;  % set the diagonal to 1
       	GeneCoReg(isnan(GeneCoReg)) = 0; % set nan to 0
    end
    
end
