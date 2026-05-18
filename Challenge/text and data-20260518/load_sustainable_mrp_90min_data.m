
% Helper script for the 90-minute Sustainable MRP Challenge
clear; clc;
load('sustainable_mrp_90min_student_data.mat');

fprintf('Loaded Sustainable MRP 90-minute challenge data.\n');
fprintf('Historical weeks: %d\n', nHist);
fprintf('Target weeks: %d\n\n', nTarget);

histDates = datetime(histWeekStartDatenum, 'ConvertFrom', 'datenum');
targetDates = datetime(targetWeekStartDatenum, 'ConvertFrom', 'datenum');

histTable = array2table(histX, 'VariableNames', cellstr(featureNames));
histTable.WeekStart = histDates;
histTable.Demand = histDemand;
histTable = movevars(histTable, 'WeekStart', 'Before', 1);

targetTable = array2table(targetX, 'VariableNames', cellstr(featureNames));
targetTable.WeekStart = targetDates;
targetTable = movevars(targetTable, 'WeekStart', 'Before', 1);

materialTable = table(cellstr(materialNames(:)), BOM_kg_per_unit(:), initialMaterialInventory_kg(:), ...
    'VariableNames', {'Material','BOM_kg_per_unit','InitialInventory_kg'});

supplierTable = table;
row = 0;
for m = 1:numel(materialNames)
    for s = 1:numel(supplierNames)
        row = row + 1;
        supplierTable.Material{row,1} = char(materialNames(m));
        supplierTable.Supplier{row,1} = char(supplierNames(s));
        supplierTable.Cost_EUR_per_kg(row,1) = supplierCost_EUR_per_kg(m,s);
        supplierTable.CO2_kg_per_kg(row,1) = supplierCO2_kg_per_kg(m,s);
        supplierTable.RecycledContent(row,1) = supplierRecycledContentShare(m,s);
        supplierTable.LeadTime_weeks(row,1) = supplierLeadTime_weeks(m,s);
        supplierTable.MaxWeeklyQty_kg(row,1) = supplierMaxWeeklyQty_kg(m,s);
    end
end

disp('First 6 historical rows:');
disp(histTable(1:6,:));
disp('Target horizon:');
disp(targetTable);
disp('Materials:');
disp(materialTable);
disp('Suppliers:');
disp(supplierTable);

fprintf('\nSubmission variables required:\n');
fprintf('  demandForecast: 12 x 1\n');
fprintf('  productionPlan: 12 x 1\n');
fprintf('  purchaseOrderQty: 12 x 3 x 2\n');
