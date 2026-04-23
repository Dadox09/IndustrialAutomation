function setup_database()
% SETUP_DATABASE  Creates the SQLite DB for the Offshore Wind Installation problem.
%   - Table Deployment_Schedule : one row per installation task
%   - Table Setup_Fuel_Matrix   : sequence-dependent fuel cost (from -> to)

    dbFile = 'offshore_wind.db';

    % Remove existing DB so the script is idempotent
    if isfile(dbFile)
        delete(dbFile);
    end

    conn = sqlite(dbFile, 'create');

    % ---------------------------------------------------------------
    % 1) Deployment_Schedule
    % ---------------------------------------------------------------
    exec(conn, [ ...
        'CREATE TABLE Deployment_Schedule (' ...
        '  TaskID           TEXT PRIMARY KEY,' ...
        '  StructureType    TEXT NOT NULL,' ...        % 'M', 'J', 'N'
        '  ProcTime         INTEGER NOT NULL,' ...     % hours
        '  WeatherWindowEnd INTEGER NOT NULL,' ...     % d_j, hours
        '  LogisticsWeight  INTEGER NOT NULL' ...      % w_j
        ');']);

    tasks = {
        'Task_01', 'M', 48, 100, 10;
        'Task_02', 'J', 72, 180,  8;
        'Task_03', 'N', 36, 120, 12;
        'Task_04', 'M', 48, 250, 10 };

    for k = 1:size(tasks,1)
        sqlStr = sprintf([ ...
            'INSERT INTO Deployment_Schedule ' ...
            '(TaskID, StructureType, ProcTime, WeatherWindowEnd, LogisticsWeight) ' ...
            'VALUES (''%s'', ''%s'', %d, %d, %d);'], ...
            tasks{k,1}, tasks{k,2}, tasks{k,3}, tasks{k,4}, tasks{k,5});
        exec(conn, sqlStr);
    end

    % ---------------------------------------------------------------
    % 2) Setup_Fuel_Matrix
    % ---------------------------------------------------------------
    % 'P' = Port Start (pseudo-source). Values from Table 2 of the assignment.
    exec(conn, [ ...
        'CREATE TABLE Setup_Fuel_Matrix (' ...
        '  FromType TEXT NOT NULL,' ...
        '  ToType   TEXT NOT NULL,' ...
        '  FuelCost INTEGER NOT NULL,' ...
        '  PRIMARY KEY (FromType, ToType)' ...
        ');']);

    setupRows = {
        % From Port
        'P','M',20; 'P','J',30; 'P','N',25;
        % From Monopile
        'M','J',50; 'M','N',30; 'M','M', 5;
        % From Jacket
        'J','M',60; 'J','N',40;
        % From Nacelle
        'N','M',25; 'N','J',35 };

    for k = 1:size(setupRows,1)
        sqlStr = sprintf([ ...
            'INSERT INTO Setup_Fuel_Matrix ' ...
            '(FromType, ToType, FuelCost) VALUES (''%s'', ''%s'', %d);'], ...
            setupRows{k,1}, setupRows{k,2}, setupRows{k,3});
        exec(conn, sqlStr);
    end

    % ---------------------------------------------------------------
    % Quick verification
    % ---------------------------------------------------------------
    fprintf('\n--- Deployment_Schedule ---\n');
    disp(fetch(conn, 'SELECT * FROM Deployment_Schedule;'));

    fprintf('--- Setup_Fuel_Matrix ---\n');
    disp(fetch(conn, 'SELECT * FROM Setup_Fuel_Matrix;'));

    close(conn);
    fprintf('Database created: %s\n', dbFile);
end
