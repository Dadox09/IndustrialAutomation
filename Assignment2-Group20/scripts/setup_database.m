function setup_database()

    dbFile = 'offshore_wind.db';

    % Remove existing DB so the script is idempotent
    if isfile(dbFile)
        delete(dbFile);
    end

    conn = sqlite(dbFile, 'create');

    % ---------------------------------------------------------------
    % 1) Deployment_Schedule
    % ---------------------------------------------------------------
    
    tasks = {
        1, 'M', 48, 10, 100;
        2, 'J', 72, 8,  180;
        3, 'N', 36, 12, 120;
        4, 'M', 48, 10, 250 };
    
    exec(conn, [ ...
        'CREATE TABLE Deployment_Schedule (' ...
        '  TaskID           INTEGER PRIMARY KEY,' ...
        '  StructureType    TEXT NOT NULL,' ...        % 'M', 'J', 'N'
        '  ProcTime         INTEGER NOT NULL,' ...     % hours
        '  LogisticsWeight INTEGER NOT NULL,' ...     % w_j
        '  WeatherWindowEnd  INTEGER NOT NULL' ...      % d_j, hours
        ');']);

    for k = 1:size(tasks,1)
        sqlStr = sprintf([ ...
            'INSERT INTO Deployment_Schedule ' ...
            '(TaskID, StructureType, ProcTime, LogisticsWeight , WeatherWindowEnd) ' ...
            'VALUES (%d, ''%s'', %d, %d, %d);'], ...
            tasks{k,1}, tasks{k,2}, tasks{k,3}, tasks{k,4}, tasks{k,5});
        exec(conn, sqlStr);
    end

    % ---------------------------------------------------------------
    % 2) Setup_Fuel_Matrix
    % ---------------------------------------------------------------
   setupRows = {
        % From Port
        'P','M',20; 'P','J',30; 'P','N',25;
        % From Monopile
        'M','J',50; 'M','N',30; 'M','M', 5;
        % From Jacket
        'J','M',60; 'J','N',40;
        % From Nacelle
        'N','M',25; 'N','J',35 };
    
    exec(conn, [ ...
        'CREATE TABLE Setup_Fuel_Matrix (' ...
        '  FromType TEXT NOT NULL,' ...
        '  ToType   TEXT NOT NULL,' ...
        '  FuelCost INTEGER NOT NULL,' ...
        '  PRIMARY KEY (FromType, ToType)' ...
        ');']);

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
