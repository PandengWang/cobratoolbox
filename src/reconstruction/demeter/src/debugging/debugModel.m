function [revisedModel,gapfilledReactions,replacedReactions]=debugModel(model,testResultsFolder, inputDataFolder,reconVersion,microbeID,biomassReaction)
% This function runs a suite of debugging functions on a refined
% reconstruction produced by the DEMETER pipeline. Tests
% are performed whether or not the models can produce biomass aerobically
% and anaerobically, and whether or not unrealistically high ATP is
% produced on the Western diet.
%
% USAGE:
%
%   [revisedModel,gapfilledReactions,replacedReactions]=debugModel(model,testResultsFolder, inputDataFolder,reconVersion,microbeID,biomassReaction)
%
% INPUTS
% model:                 COBRA model structure
% testResultsFolder:     Folder where the test results are saved
% inputDataFolder:       Folder with input tables with experimental data
%                        and databases that inform the refinement process
% reconVersion:          Name of the refined reconstruction resource
% microbeID:             ID of the reconstructed microbe that serves as
%                        the reconstruction name and to identify it in
%                        input tables
% biomassReaction:       Reaction ID of the biomass objective function
%
% OUTPUT
% revisedModel:          Gapfilled COBRA model structure
% gapfilledReactions:    Reactions gapfilled to enable flux
% replacedReactions:     Reactions replaced because they were causing
%                        futile cycles
%
% .. Author:
%       - Almut Heinken, 09/2020

gapfilledReactions = {};
cntGF=1;
replacedReactions = {};

tol=0.0000001;

model=changeObjective(model,biomassReaction);

% implement Western diet
WesternDiet = readtable('WesternDietAGORA2.txt', 'Delimiter', 'tab');
WesternDiet=table2cell(WesternDiet);
WesternDiet=cellstr(string(WesternDiet));

% Load reaction and metabolite database
metaboliteDatabase = readtable('MetaboliteDatabase.txt', 'Delimiter', 'tab','TreatAsEmpty',['UND. -60001','UND. -2011','UND. -62011'], 'ReadVariableNames', false);
metaboliteDatabase=table2cell(metaboliteDatabase);
database.metabolites=metaboliteDatabase;
for i=1:size(database.metabolites,1)
    database.metabolites{i,5}=num2str(database.metabolites{i,5});
    database.metabolites{i,7}=num2str(database.metabolites{i,7});
    database.metabolites{i,8}=num2str(database.metabolites{i,8});
end
reactionDatabase = readtable('ReactionDatabase.txt', 'Delimiter', 'tab','TreatAsEmpty',['UND. -60001','UND. -2011','UND. -62011'], 'ReadVariableNames', false);
reactionDatabase=table2cell(reactionDatabase);
database.reactions=reactionDatabase;

[AerobicGrowth, AnaerobicGrowth] = testGrowth(model, biomassReaction);
if AnaerobicGrowth(1,1) < tol
    % find reactions that are preventing the model from growing
    % anaerobically
    [model,condGF,targetGF,relaxGF] = runGapfillingFunctions(model,biomassReaction,biomassReaction,'max',database);
    % export the gapfilled reactions
    if ~isempty(condGF)
        gapfilledReactions{cntGF,1}=microbeID;
        gapfilledReactions{cntGF,2}='Enabling anaerobic growth';
        gapfilledReactions{cntGF,3}='Condition-specific gapfilling';
        gapfilledReactions(cntGF,4:length(condGF)+3)=condGF;
        cntGF=cntGF+1;
    end
    if ~isempty(targetGF)
        gapfilledReactions{cntGF,1}=microbeID;
        gapfilledReactions{cntGF,2}='Enabling anaerobic growth';
        gapfilledReactions{cntGF,3}='Targeted gapfilling';
        gapfilledReactions(cntGF,4:length(targetGF)+3)=targetGF;
        cntGF=cntGF+1;
    end
    if ~isempty(relaxGF)
        gapfilledReactions{cntGF,1}=microbeID;
        gapfilledReactions{cntGF,2}='Enabling anaerobic growth';
        gapfilledReactions{cntGF,3}='Gapfilling based on relaxFBA';
        gapfilledReactions(cntGF,4:length(relaxGF)+3)=relaxGF;
        cntGF=cntGF+1;
    end
end

[AerobicGrowth, AnaerobicGrowth] = testGrowth(model, biomassReaction);
if AerobicGrowth(1,2) < tol
    % identify blocked reactions on Western diet
    model=useDiet(model,WesternDiet);
    [model,condGF,targetGF,relaxGF] = runGapfillingFunctions(model,biomassReaction,biomassReaction,'max',database);
    % export the gapfilled reactions
    if ~isempty(condGF)
        gapfilledReactions{cntGF,1}=microbeID;
        gapfilledReactions{cntGF,2}='Growth on Western diet';
        gapfilledReactions{cntGF,3}='Condition-specific gapfilling';
        gapfilledReactions(cntGF,4:length(condGF)+3)=condGF;
        cntGF=cntGF+1;
    end
    if ~isempty(targetGF)
        gapfilledReactions{cntGF,1}=microbeID;
        gapfilledReactions{cntGF,2}='Growth on Western diet';
        gapfilledReactions{cntGF,3}='Targeted gapfilling';
        gapfilledReactions(cntGF,4:length(targetGF)+3)=targetGF;
        cntGF=cntGF+1;
    end
    if ~isempty(relaxGF)
        gapfilledReactions{cntGF,1}=microbeID;
        gapfilledReactions{cntGF,2}='Growth on Western diet';
        gapfilledReactions{cntGF,3}='Gapfilling based on relaxFBA';
        gapfilledReactions(cntGF,4:length(relaxGF)+3)=relaxGF;
        cntGF=cntGF+1;
    end
end

% identify blocked biomass precursors on defined medium for the organism
[growsOnDefinedMedium,constrainedModel,~] = testGrowthOnDefinedMedia(model, microbeID, biomassReaction, inputDataFolder);
if growsOnDefinedMedium == 0
    % find reactions that are preventing the model from growing
    [model,condGF,targetGF,relaxGF] = runGapfillingFunctions(model,biomassReaction,biomassReaction,'max',database);
    % export the gapfilled reactions
    if ~isempty(condGF)
        gapfilledReactions{cntGF,1}=microbeID;
        gapfilledReactions{cntGF,2}='Growth on defined medium';
        gapfilledReactions{cntGF,3}='Condition-specific gapfilling';
        gapfilledReactions(cntGF,4:length(condGF)+3)=condGF;
        cntGF=cntGF+1;
    end
    if ~isempty(targetGF)
        gapfilledReactions{cntGF,1}=microbeID;
        gapfilledReactions{cntGF,2}='Growth on defined medium';
        gapfilledReactions{cntGF,3}='Targeted gapfilling';
        gapfilledReactions(cntGF,4:length(targetGF)+3)=targetGF;
        cntGF=cntGF+1;
    end
    if ~isempty(relaxGF)
        gapfilledReactions{cntGF,1}=microbeID;
        gapfilledReactions{cntGF,2}='Growth on defined medium';
        gapfilledReactions{cntGF,3}='Gapfilling based on relaxFBA';
        gapfilledReactions(cntGF,4:length(relaxGF)+3)=relaxGF;
        cntGF=cntGF+1;
    end
end

% load all test result files for experimental data
dInfo = dir([testResultsFolder filesep reconVersion '_refined']);
fileList={dInfo.name};
fileList=fileList';
fileList(~(contains(fileList(:,1),{'.txt'})),:)=[];
fileList(~(contains(fileList(:,1),{'FalseNegatives'})),:)=[];

% if there are any false negative predictions
% find what reactions should be added to enable agreement with experimental
% data
if size(fileList,1)>0
    for i=1:size(fileList,1)
        % define if objective should be maximized or minimized
        if any(contains(fileList{i,1},{'Carbon_sources','Metabolite_uptake'}))
            osenseStr = 'min';
        elseif any(contains(fileList{i,1},{'Fermentation_products','Secretion_products'}))
            osenseStr = 'max';
        end
        FNlist = readtable([[testResultsFolder filesep reconVersion '_refined'] filesep fileList{i,1}], 'ReadVariableNames', false, 'Delimiter', 'tab');
        FNlist = table2cell(FNlist);
        FNs = FNlist(find(strcmp(FNlist(:,1),microbeID)),2:end);
        FNs = FNs(~cellfun(@isempty, FNs));
        if ~isempty(FNs)
            for j=1:length(FNs)
                metExch=['EX_' database.metabolites{find(strcmp(database.metabolites(:,2),FNs{j})),1} '(e)'];
                % find reactions that could be gap-filled to enable flux
                [model,condGF,targetGF,relaxGF] = runGapfillingFunctions(model,metExch,biomassReaction,osenseStr,database);
                % export the gapfilled reactions
                if ~isempty(condGF)
                    gapfilledReactions{cntGF,1}=microbeID;
                    gapfilledReactions{cntGF,2}=FNs{j};
                    gapfilledReactions{cntGF,3}='Condition-specific gapfilling';
                    gapfilledReactions(cntGF,4:length(condGF)+3)=condGF;
                    cntGF=cntGF+1;
                end
                if ~isempty(targetGF)
                    gapfilledReactions{cntGF,1}=microbeID;
                    gapfilledReactions{cntGF,2}=FNs{j};
                    gapfilledReactions{cntGF,3}='Targeted gapfilling';
                    gapfilledReactions(cntGF,4:length(targetGF)+3)=targetGF;
                    cntGF=cntGF+1;
                end
                if ~isempty(relaxGF)
                    gapfilledReactions{cntGF,1}=microbeID;
                    gapfilledReactions{cntGF,2}=FNs{j};
                    gapfilledReactions{cntGF,3}='Gapfilling based on relaxFBA';
                    gapfilledReactions(cntGF,4:length(relaxGF)+3)=relaxGF;
                    cntGF=cntGF+1;
                end
            end
        end
    end
end

% remove futile cycles if any exist
[atpFluxAerobic, atpFluxAnaerobic] = testATP(model);
if atpFluxAerobic > 150 || atpFluxAnaerobic > 100
    % let us try if running removeFutileCycles again will work
    [model, deletedRxns, addedRxns] = removeFutileCycles(model, biomassReaction, database);
    replacedReactions{1,1}=microbeID;
    replacedReactions{1,2}='Futile cycle correction';
    replacedReactions{1,3}='To replace';
    replacedReactions(1,4:length(deletedRxns)+3)=deletedRxns;
end

% rebuild and export the model
revisedModel = rebuildModel(model,database);
revisedModel=changeObjective(revisedModel,biomassReaction);

end