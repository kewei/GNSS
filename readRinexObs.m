
function [XYZ_station,obs,observablesHeader,measurementsInterval]=readRinex302(filePath)
%% This function opens RINEX 3.02 observation files.
% Follows RINEX 3.02 standard. Reads Multiconstellation observables and
% generates an output matrix

%%% ------ Input--- %%%%%%%%%%
%
%   filePath : path to the RINEX observables file
%
%%% ------ Output--- %%%%%%%%%%
%
%   XYZ_station: ECEF coordinates of reference station or point (estimated by receiver)
%
%   observablesHeader: Cell array containing information of observables for
%   each constellation. to look for GPS information type
%   observablesHeader{'G'}
%
%   obs: Matrix containing observables {'week' 'epoch' 'flag' 'prn' 'C1C' 'D1C' 'S1C'}
%       Different for each constellation.
%
% This functions uses functions str2doubleq for quick conversion from
% string to double. It also uses function Date2GPSTime to convert a date to
% TOW.

'Loading observables...'
idFile  = fopen (filePath);

generalHeader = {'week', 'epoch', 'flag', 'prn'};

%Initialzie values
measurementsInterval = -1;

%% Read header
while (true)
    
    line = fgetl(idFile);                                                   %get line
    splitLine = strsplit(line);                                             %Line splited by spaces
    
    if strfind(line,'APPROX POSITION XYZ')                                  % Receiver aprox position
        XYZ_station=real(str2doubleq(line(1:60)));
        
        
        
    elseif ~isempty(strfind(line,'SYS / # / OBS TYPES'))                    % Observation types for the different constellations (C1C, D1 and S1 only  )
        constellation = line(1);
        if constellation        == 'G'
            hasGps = 1;
        elseif constellation    == 'R'
            hasGlonass = 1;
        elseif constellation    == 'C'
            hasBeidou = 1;
            
        %% added by Kewei Zhang 
         % 2018-09-11
        elseif constellation    == 'E'
            hasGalileo = 1;
        elseif constellation    == 'S'
            hasSbas = 1;
        end
        
        nObservables = str2doubleq(line(2:7));                                  % Number of observables
        %% modified by Kewei Zhang
        % 2018-09-11
        %observables = splitLine(3:end - 7);                                     % Take the observables only (Not the text regions)
        observables = splitLine(3:end - 6);                                     % Take the observables only (Not the text regions)
        observables = [generalHeader, observables];                             % Append the header, as the data will be ordered like specified in obsrvables now.
        
        if nObservables >13 %Two line case
            line2 = fgetl(idFile);
            splitLine2 = strsplit(line2);
            %% modified by Kewei Zhang
            % 2018-09-11
            %observables = [observables, splitLine2(2:end - 7) ];
            observables = [observables, splitLine2(2:end - 6) ];
        end
        
        observablesHeader{uint8(constellation)} = observables;                  % Contains all the observables for the constellations.
        %use constellation letter for indexation
        
    elseif strfind(line,'INTERVAL')
        measurementsInterval=str2doubleq(line(5:10));                       % Measurement intervals (Default 1)
        
        
    elseif strfind(line,'END OF HEADER');
        break;                                                              % End of header loop
    end
end




if measurementsInterval == -1                                               %If itnerval not set interval = 1
    measurementsInterval = 1;
end
%% Read body
%% Modified by Kewei Zhang
% add more systems
% 2018-09-11
obs.gps = [];                                                                   % Output matrix
obs.galileo = [];
obs.glonass = [];
obs.sbas = [];
obs.beidou = [];

epoch = 0;                                                                  % Epoch counter
nObs.gps = 1;
nObs.glonass = 1;
nObs.galileo = 1;
nObs.beidou = 1;
nObs.sbas = 1;

while(~feof(idFile))                                                        % Until end of file
    line = fgetl(idFile);                                                   % Get line
    splitLine = strsplit(line);                                             % Split line by spaces
    
    if strfind(line, '>')                                                   % New epoch
        epoch = epoch + 1;
        %Read time
        year = str2doubleq(splitLine(2));
        month = str2doubleq(splitLine(3));
        day = str2doubleq(splitLine(4));
        hour = str2doubleq(splitLine(5));
        minute = str2doubleq(splitLine(6));
        second = str2doubleq(splitLine(7));
        time = [year, month, day, hour, minute, second];
        time=real(time);
        [tow,gpsWeek]=Date2GPSTime(time(1),time(2),time(3),time(4)+time(5)/60+time(6)/3600); %Transform date to seconds of week
        
        currentEpoch = tow;                                                 % Output
        currentSatellites = str2doubleq(splitLine(9));                      % Satellite information
        currentFlag = str2doubleq(splitLine(8));                            % flag (use/not use)
        
    else
        error 'Loading not correct, satellites skiped'                     % Simple check, it should never jump if using the right rinex version
    end
    
    if currentSatellites == 0
        'No satellites in epoch'
    end
    
    for i = 1:real(currentSatellites)                                       % Read the epoch satellites
        line = fgetl(idFile);
        constellation = line(1);                                            % First character indicates de constellation
        prn = str2doubleq ([line(2) line(3)]);                              % Satellites PRN number
        
        nObservables = cellfun('length',observablesHeader(uint8(constellation))) - 4; %The header also includes things that are not measurements
        measurementsPosition = (4:16:16*nObservables+4);                    %Vector containing the columns of the measurements. Each 16 columns theres a measurement
        %% Commented out by Kewei Zhang
        % 2018-09-11
%         if measurementsPosition(end) > length(line)
%             measurementsPosition(end) = length(line);       %Correction of a wierd bug
%         end
        
        measurementsValue = zeros(1,nObservables); %Initialize vector to store data
        for m = 1:nObservables % Number of observables in the line (Generally 3)
            %% Modified by Kewei Zhang
            % because not all satellites have all observations
            % 2018-09-11
            if measurementsPosition(m) < length(line) && measurementsPosition(m+1) <= length(line)
                value = line(measurementsPosition(m):measurementsPosition(m+1)); % Column position of measurement. Measurements take 16 columns
                value = value(~isspace(value));
                measurementsValue(m) = str2doubleq(value);                      % convert string to double
            elseif measurementsPosition(m) < length(line) && measurementsPosition(m+1) > length(line)
                value = line(measurementsPosition(m):end); % Column position of measurement. Measurements take 16 columns
                value = value(~isspace(value));
                measurementsValue(m) = str2doubleq(value);
            end
        end
        
        measurementsValue = real(measurementsValue);                        % output of str2doubleq is imaginary
        if measurementsValue(1) == 0                                        % if PSR value equals 0
            continue;                                                       % Skip line (Satellite has no information on L1)
        end
        switch constellation                                                %Asign constellation based on first char of line
            %% Modified by Kewei Zhang
            % add more constealltions
            case 'G' %GPS
                prn = prn+1000;
                data = [gpsWeek, currentEpoch,currentFlag,prn,measurementsValue];   % store data
                obs.gps{nObs.gps} = real(data);
                nObs.gps= nObs.gps+1;
            case 'R'
                prn = prn+2000;
                data = [gpsWeek, currentEpoch,currentFlag,prn,measurementsValue];   % store data
                obs.glonass{nObs.glonass} = real(data);
                nObs.glonass= nObs.glonass+1;
            case 'S'
                prn = prn+3000;
                data = [gpsWeek, currentEpoch,currentFlag,prn,measurementsValue];   % store data
                obs.sbas{nObs.sbas} = real(data);
                nObs.sbas= nObs.sbas+1;
            case 'E'
                prn = prn+4000;
                data = [gpsWeek, currentEpoch,currentFlag,prn,measurementsValue];   % store data
                obs.galileo{nObs.sbas} = real(data);
                nObs.galileo= nObs.galileo+1;
            case 'C'
                prn = prn+5000;
                data = [gpsWeek, currentEpoch,currentFlag,prn,measurementsValue];   % store data
                obs.beidou{nObs.beidou} = real(data);
                nObs.beidou= nObs.beidou+1;
            otherwise
                error 'Unrecognized constellation'                          %Probably 'J' for QZSS
        end
        
        %% commented out by Kewei Zhang
%         data = [gpsWeek, currentEpoch,currentFlag,prn,measurementsValue];   % store data
%         obs{nObs} = real(data);
%         nObs= nObs+1;
    end
    
    
end

%Convert cell array to matrix. This is necesary to adapt to the rest of the
%alogrithm. Might give problems when different constellations have more
%observables.
%% Modified by Kewei Zhang
% record all the systems observations
% 2018-09-11
obs.gps = cell2mat(obs.gps');
obs.galileo = cell2mat(obs.galileo');
obs.glonass = cell2mat(obs.glonass');
obs.sbas = cell2mat(obs.sbas');
obs.beidou = cell2mat(obs.beidou');

'Observables loaded'
fclose(idFile);