% ========================================================================
% MECANOMIOGRAFÍA (MMG) PROCESAMIENTO DE SEÑAL Y ANÁLISIS
% V.3 Con ventanas de RMS, MDF y MPF + Symmetry Index
% ========================================================================
clear all; close all;

%% ========== CONFIGURACIÓN ==========
fprintf('\n╔══════════════════════════════╗\n');
fprintf('║   MECANOMIOGRAFÍA PROCESAMIENTO DE SEÑAL         ║\n');
fprintf('║   Análisis MMG multi-sensor                      ║\n');
fprintf('╚══════════════════════════════════════════════════╝\n\n');

% Cerrar conexiones previas
delete(instrfind);

% Parámetros de adquisición
puerto = 'COM9';
baudrate = 921600;

fprintf(' MODO DE ADQUISICIÓN:\n');
fprintf('   La adquisición continuará hasta que presiones ESPACIO\n');

% PARÁMETROS DEL FILTRO
fc_low = 10;    % Hz
fc_high = 50;   % Hz
orden_filtro = 4;

% PARÁMETROS DE ANÁLISIS POR VENTANAS
tamano_ventana = 1.0;  % segundos
overlap_ventana = 0;   % solapamiento

% --- Configuración bilateral ---
modo_bilateral = false;

% Solicitar nombre del archivo
nombre_archivo = input('Nombre del archivo para guardar datos: ', 's');
if isempty(nombre_archivo)
    nombre_archivo = sprintf('datos_mmg_%s', datestr(now, 'yyyymmdd_HHMMSS'));
end

% ---- CREAR CARPETA DE SALIDA ----
carpeta_salida = nombre_archivo;
if ~exist(carpeta_salida, 'dir')
    mkdir(carpeta_salida);
end
nombre_completo = fullfile(carpeta_salida, [nombre_archivo '.mat']);

fprintf('\n Los datos se guardarán en la carpeta: %s\n', carpeta_salida);

%% ========== CONECTAR A ESP32 ==========
fprintf('\n▶ Conectando al puerto %s a %d baud...\n', puerto, baudrate);
s = serialport(puerto, baudrate);
configureTerminator(s, "LF");
flush(s);

pause(2);
fprintf('Conexión establecida. Esperando señal INICIO del ESP32...\n');

timeout = tic;
while toc(timeout) < 15
    if s.NumBytesAvailable > 0
        linea = readline(s);
        fprintf('   %s\n', linea);
        if contains(linea, "INICIO")
            break;
        end
    end
    pause(0.1);
end

fprintf('▶ Descartando primeras muestras...\n');
flush(s);
pause(0.5);

%% ========== PREPARAR FIGURA TIEMPO REAL ==========
fig_realtime = figure('Position', [50 50 1900 950], 'Name', 'MMG Acquisition - Real Time');

fprintf('\n╔════════════════════════════════════════════════════════╗\n');
fprintf('║   PRESIONA LA TECLA ESPACIO PARA DETENER               ║\n');
fprintf('╚════════════════════════════════════════════════════════╝\n\n');

set(fig_realtime, 'KeyPressFcn', @(src,event) stopAcquisition(event));
global stopFlag;
stopFlag = false;

% SENSOR 1
subplot(4,3,1);
hS1_X = animatedline('Color','r','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 1 - Eje X', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

subplot(4,3,2);
hS1_Y = animatedline('Color','g','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 1 - Eje Y', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

subplot(4,3,3);
hS1_Z = animatedline('Color','b','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 1 - Eje Z', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

% SENSOR 2
subplot(4,3,4);
hS2_X = animatedline('Color','r','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 2 - Eje X', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

subplot(4,3,5);
hS2_Y = animatedline('Color','g','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 2 - Eje Y', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

subplot(4,3,6);
hS2_Z = animatedline('Color','b','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 2 - Eje Z', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

% SENSOR 3
subplot(4,3,7);
hS3_X = animatedline('Color','r','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 3 - Eje X', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

subplot(4,3,8);
hS3_Y = animatedline('Color','g','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 3 - Eje Y', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

subplot(4,3,9);
hS3_Z = animatedline('Color','b','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 3 - Eje Z', 'FontSize', 10, 'FontWeight', 'bold');
ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

% SENSOR 4
subplot(4,3,10);
hS4_X = animatedline('Color','r','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 4 - Eje X', 'FontSize', 10, 'FontWeight', 'bold');
xlabel('Tiempo (s)'); ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

subplot(4,3,11);
hS4_Y = animatedline('Color','g','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 4 - Eje Y', 'FontSize', 10, 'FontWeight', 'bold');
xlabel('Tiempo (s)'); ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

subplot(4,3,12);
hS4_Z = animatedline('Color','b','LineWidth',1.5,'MaximumNumPoints',2000);
grid on; box on;
title('SENSOR 4 - Eje Z', 'FontSize', 10, 'FontWeight', 'bold');
xlabel('Tiempo (s)'); ylabel('Aceleración (g)'); ylim([-0.5 0.5]);

%% ========== ADQUISICIÓN ==========
fprintf('╔══════════════════════════════════════════════════════╗\n');
fprintf('║   INICIANDO ADQUISICIÓN                                ║\n');
fprintf('║   Sensores activos: 4                                  ║\n');
fprintf('║   >>>   ESPACIO PARA DETENER <<<                       ║\n');
fprintf('╚════════════════════════════════════════════════════════╝\n\n');

tiempo = [];
accel1_X = []; accel1_Y = []; accel1_Z = [];
accel2_X = []; accel2_Y = []; accel2_Z = [];
accel3_X = []; accel3_Y = []; accel3_Z = [];
accel4_X = []; accel4_Y = []; accel4_Z = [];

tic;
i = 1;
muestras_perdidas = 0;

while ~stopFlag
    try
        if s.NumBytesAvailable > 0
            linea = readline(s);
            valores = str2double(split(linea, ','));

            if length(valores) == 12 && all(~isnan(valores))
                tiempo(i) = toc;

                accel1_X(i) = valores(1);  accel1_Y(i) = valores(2);  accel1_Z(i) = valores(3);
                accel2_X(i) = valores(4);  accel2_Y(i) = valores(5);  accel2_Z(i) = valores(6);
                accel3_X(i) = valores(7);  accel3_Y(i) = valores(8);  accel3_Z(i) = valores(9);
                accel4_X(i) = valores(10); accel4_Y(i) = valores(11); accel4_Z(i) = valores(12);

                if mod(i, 5) == 0
                    t = tiempo(i);
                    addpoints(hS1_X, t, accel1_X(i)); addpoints(hS1_Y, t, accel1_Y(i)); addpoints(hS1_Z, t, accel1_Z(i));
                    addpoints(hS2_X, t, accel2_X(i)); addpoints(hS2_Y, t, accel2_Y(i)); addpoints(hS2_Z, t, accel2_Z(i));
                    addpoints(hS3_X, t, accel3_X(i)); addpoints(hS3_Y, t, accel3_Y(i)); addpoints(hS3_Z, t, accel3_Z(i));
                    addpoints(hS4_X, t, accel4_X(i)); addpoints(hS4_Y, t, accel4_Y(i)); addpoints(hS4_Z, t, accel4_Z(i));
                    drawnow limitrate;
                end

                i = i + 1;
            else
                muestras_perdidas = muestras_perdidas + 1;
            end
        end

        if mod(i, 50) == 0
            sgtitle(fig_realtime, sprintf('ADQUISICIÓN EN CURSO - Tiempo: %.1f s | PRESIONA ESPACIO PARA DETENER', toc), ...
                'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0.5 0]);
        end

    catch ME
        muestras_perdidas = muestras_perdidas + 1;
    end
end

delete(s);
duracion = tiempo(end);

%% ========== ESTADÍSTICAS ADQUISICIÓN ==========
fs_real = length(tiempo) / duracion;
fprintf('\n╔═════════════════════════════════════════════════════╗\n');
fprintf('║   ADQUISICIÓN COMPLETADA                              ║\n');
fprintf('╠═══════════════════════════════════════════════════════╣\n');
fprintf('║   Duración real: %.2f s\n', duracion);
fprintf('║   Muestras obtenidas: %d\n', length(tiempo));
fprintf('║   Frecuencia de muestreo: %.2f Hz\n', fs_real);
fprintf('║   Muestras perdidas: %d (%.2f%%)\n', muestras_perdidas, 100*muestras_perdidas/(i+muestras_perdidas));
fprintf('╚═══════════════════════════════════════════════════════╝\n\n');

%% ========== PROCESAMIENTO ==========
fprintf('▶ Removiendo componente DC...\n');

senal1_X = accel1_X - mean(accel1_X); senal1_Y = accel1_Y - mean(accel1_Y); senal1_Z = accel1_Z - mean(accel1_Z);
senal2_X = accel2_X - mean(accel2_X); senal2_Y = accel2_Y - mean(accel2_Y); senal2_Z = accel2_Z - mean(accel2_Z);
senal3_X = accel3_X - mean(accel3_X); senal3_Y = accel3_Y - mean(accel3_Y); senal3_Z = accel3_Z - mean(accel3_Z);
senal4_X = accel4_X - mean(accel4_X); senal4_Y = accel4_Y - mean(accel4_Y); senal4_Z = accel4_Z - mean(accel4_Z);

fprintf('▶ Filtro Butterworth pasabanda %.1f–%.1f Hz, orden %d...\n', fc_low, fc_high, orden_filtro);

if fs_real < 2 * fc_high
    warning('Frecuencia de muestreo baja, ajustando fc_high...');
    fc_high = fs_real / 2.5;
    fprintf('  Nuevo fc_high: %.1f Hz\n', fc_high);
end

[b, a] = butter(orden_filtro, [fc_low fc_high]/(fs_real/2), 'bandpass');

senal1_X_filt = filtfilt(b,a,senal1_X); senal1_Y_filt = filtfilt(b,a,senal1_Y); senal1_Z_filt = filtfilt(b,a,senal1_Z);
senal2_X_filt = filtfilt(b,a,senal2_X); senal2_Y_filt = filtfilt(b,a,senal2_Y); senal2_Z_filt = filtfilt(b,a,senal2_Z);
senal3_X_filt = filtfilt(b,a,senal3_X); senal3_Y_filt = filtfilt(b,a,senal3_Y); senal3_Z_filt = filtfilt(b,a,senal3_Z);
senal4_X_filt = filtfilt(b,a,senal4_X); senal4_Y_filt = filtfilt(b,a,senal4_Y); senal4_Z_filt = filtfilt(b,a,senal4_Z);

fprintf(' Filtrado completado.\n\n');

%% ========== PARÁMETROS GLOBALES ==========
fprintf('▶ Calculando parámetros globales...\n');

params.sensor1.RMS_X_raw = rms(senal1_X); params.sensor1.RMS_Y_raw = rms(senal1_Y); params.sensor1.RMS_Z_raw = rms(senal1_Z);
params.sensor1.RMS_X_filt = rms(senal1_X_filt); params.sensor1.RMS_Y_filt = rms(senal1_Y_filt); params.sensor1.RMS_Z_filt = rms(senal1_Z_filt);

params.sensor2.RMS_X_raw = rms(senal2_X); params.sensor2.RMS_Y_raw = rms(senal2_Y); params.sensor2.RMS_Z_raw = rms(senal2_Z);
params.sensor2.RMS_X_filt = rms(senal2_X_filt); params.sensor2.RMS_Y_filt = rms(senal2_Y_filt); params.sensor2.RMS_Z_filt = rms(senal2_Z_filt);

params.sensor3.RMS_X_raw = rms(senal3_X); params.sensor3.RMS_Y_raw = rms(senal3_Y); params.sensor3.RMS_Z_raw = rms(senal3_Z);
params.sensor3.RMS_X_filt = rms(senal3_X_filt); params.sensor3.RMS_Y_filt = rms(senal3_Y_filt); params.sensor3.RMS_Z_filt = rms(senal3_Z_filt);

params.sensor4.RMS_X_raw = rms(senal4_X); params.sensor4.RMS_Y_raw = rms(senal4_Y); params.sensor4.RMS_Z_raw = rms(senal4_Z);
params.sensor4.RMS_X_filt = rms(senal4_X_filt); params.sensor4.RMS_Y_filt = rms(senal4_Y_filt); params.sensor4.RMS_Z_filt = rms(senal4_Z_filt);

N = length(senal1_Z_filt);
f = fs_real*(0:(floor(N/2)))/N;

calcular_freq_params = @(senal) struct('MPF', meanfreq(senal, fs_real), 'MDF', medfreq(senal, fs_real));

params.sensor1.freq_Z = calcular_freq_params(senal1_Z_filt);
params.sensor2.freq_Z = calcular_freq_params(senal2_Z_filt);
params.sensor3.freq_Z = calcular_freq_params(senal3_Z_filt);
params.sensor4.freq_Z = calcular_freq_params(senal4_Z_filt);

fprintf(' Parámetros globales calculados.\n\n');

%% ========== ANÁLISIS POR VENTANAS ==========
fprintf('╔════════════════════════════════════════════════════════╗\n');
fprintf('║   ANÁLISIS POR VENTANAS TEMPORALES                     ║\n');
fprintf('║   Ventana: %.1f s | Overlap: %.0f%%                   ║\n', tamano_ventana, overlap_ventana*100);
fprintf('╚════════════════════════════════════════════════════════╝\n\n');

muestras_por_ventana = round(tamano_ventana * fs_real);
num_muestras_total   = length(senal1_Z_filt);
nVentanas            = floor(num_muestras_total / muestras_por_ventana);

fprintf('▶ Número de ventanas a procesar: %d\n', nVentanas);
fprintf('▶ Muestras por ventana: %d\n\n', muestras_por_ventana);

MDF_temporal   = zeros(nVentanas, 4, 3);
MPF_temporal   = zeros(nVentanas, 4, 3);
RMS_temporal   = zeros(nVentanas, 4, 3);
tiempo_ventanas = zeros(nVentanas, 1);

senales_filt = zeros(num_muestras_total, 4, 3);
senales_filt(:,1,1) = senal1_X_filt(:); senales_filt(:,1,2) = senal1_Y_filt(:); senales_filt(:,1,3) = senal1_Z_filt(:);
senales_filt(:,2,1) = senal2_X_filt(:); senales_filt(:,2,2) = senal2_Y_filt(:); senales_filt(:,2,3) = senal2_Z_filt(:);
senales_filt(:,3,1) = senal3_X_filt(:); senales_filt(:,3,2) = senal3_Y_filt(:); senales_filt(:,3,3) = senal3_Z_filt(:);
senales_filt(:,4,1) = senal4_X_filt(:); senales_filt(:,4,2) = senal4_Y_filt(:); senales_filt(:,4,3) = senal4_Z_filt(:);

fprintf('▶ Procesando ventanas...\n');

for ventana = 1:nVentanas
    inicio = (ventana-1) * muestras_por_ventana + 1;
    fin    = ventana * muestras_por_ventana;
    tiempo_ventanas(ventana) = mean(tiempo(inicio:fin));

    for sensor = 1:4
        for eje = 1:3
            segmento = senales_filt(inicio:fin, sensor, eje);
            RMS_temporal(ventana, sensor, eje) = rms(segmento);
            [Pxx, f_psd] = periodogram(segmento, hamming(length(segmento)), [], fs_real);
            MPF_temporal(ventana, sensor, eje) = meanfreq(Pxx, f_psd);
            MDF_temporal(ventana, sensor, eje) = medfreq(Pxx, f_psd);
        end
    end

    if mod(ventana, 10) == 0
        fprintf('   Ventanas procesadas: %d/%d\n', ventana, nVentanas);
    end
end

fprintf('Análisis por ventanas completado.\n\n');

pendientes_MDF = zeros(4, 3);
pendientes_MPF = zeros(4, 3);
pendientes_RMS = zeros(4, 3);

for sensor = 1:4
    for eje = 1:3
        p_mdf = polyfit(tiempo_ventanas, MDF_temporal(:,sensor,eje), 1);
        p_mpf = polyfit(tiempo_ventanas, MPF_temporal(:,sensor,eje), 1);
        p_rms = polyfit(tiempo_ventanas, RMS_temporal(:,sensor,eje), 1);
        pendientes_MDF(sensor, eje) = p_mdf(1);
        pendientes_MPF(sensor, eje) = p_mpf(1);
        pendientes_RMS(sensor, eje) = p_rms(1);
    end
end

%% ========== SYMMETRY INDEX (modo bilateral) ==========
if modo_bilateral
    fprintf('▶ Calculando Symmetry Index y Symmetry Angle...\n');

    SI_global = struct();
    SA_global = struct();

    RMS_izq_g = (params.sensor1.RMS_Z_filt + params.sensor2.RMS_Z_filt) / 2;
    RMS_der_g = (params.sensor3.RMS_Z_filt + params.sensor4.RMS_Z_filt) / 2;

    SI_global.RMS = (RMS_der_g - RMS_izq_g) / (0.5*(RMS_der_g + RMS_izq_g)) * 100;
    SA_global.RMS = atan((RMS_izq_g - RMS_der_g) / (RMS_izq_g + RMS_der_g)) * (180/pi) * 2;

    fprintf('   Índice de simetría RMS: %.2f%%\n', SI_global.RMS);
    fprintf('   Ángulo de simetría  RMS: %.2f°\n',  SA_global.RMS);

    if abs(SI_global.RMS) < 10
        fprintf('   -> Simetría normal\n');
    elseif abs(SI_global.RMS) < 15
        fprintf('   -> Asimetría leve\n');
    else
        fprintf('   -> Asimetría marcada\n');
    end

    SI_temporal = zeros(nVentanas, 1);
    for v = 1:nVentanas
        r_izq = (RMS_temporal(v,1,3) + RMS_temporal(v,2,3)) / 2;
        r_der = (RMS_temporal(v,3,3) + RMS_temporal(v,4,3)) / 2;
        SI_temporal(v) = (r_der - r_izq) / (0.5*(r_der + r_izq)) * 100;
    end

    fprintf('\n');
end

%% ========== IMPRIMIR ESTADÍSTICAS ==========
fprintf('╔════════════════════════════════════════════════════════╗\n');
fprintf('║   PARÁMETROS GLOBALES CALCULADOS                       ║\n');
fprintf('╠════════════════════════════════════════════════════════╣\n');
fprintf('║ SENSOR 1 (Eje Z): RMS=%.4fg | MPF=%.2fHz | MDF=%.2fHz\n', params.sensor1.RMS_Z_filt, params.sensor1.freq_Z.MPF, params.sensor1.freq_Z.MDF);
fprintf('║ SENSOR 2 (Eje Z): RMS=%.4fg | MPF=%.2fHz | MDF=%.2fHz\n', params.sensor2.RMS_Z_filt, params.sensor2.freq_Z.MPF, params.sensor2.freq_Z.MDF);
fprintf('║ SENSOR 3 (Eje Z): RMS=%.4fg | MPF=%.2fHz | MDF=%.2fHz\n', params.sensor3.RMS_Z_filt, params.sensor3.freq_Z.MPF, params.sensor3.freq_Z.MDF);
fprintf('║ SENSOR 4 (Eje Z): RMS=%.4fg | MPF=%.2fHz | MDF=%.2fHz\n', params.sensor4.RMS_Z_filt, params.sensor4.freq_Z.MPF, params.sensor4.freq_Z.MDF);
fprintf('╚════════════════════════════════════════════════════════╝\n\n');

fprintf('╔════════════════════════════════════════════════════════╗\n');
fprintf('║   ÍNDICES DE FATIGA (Pendientes Eje Z)                 ║\n');
fprintf('╠════════════════════════════════════════════════════════╣\n');
fprintf('║ SENSOR 1: MDF %.4f Hz/s | RMS %.4f g/s\n', pendientes_MDF(1,3), pendientes_RMS(1,3));
fprintf('║ SENSOR 2: MDF %.4f Hz/s | RMS %.4f g/s\n', pendientes_MDF(2,3), pendientes_RMS(2,3));
fprintf('║ SENSOR 3: MDF %.4f Hz/s | RMS %.4f g/s\n', pendientes_MDF(3,3), pendientes_RMS(3,3));
fprintf('║ SENSOR 4: MDF %.4f Hz/s | RMS %.4f g/s\n', pendientes_MDF(4,3), pendientes_RMS(4,3));
fprintf('╠════════════════════════════════════════════════════════╣\n');

%% ========== FIGURAS ==========
fprintf('▶ Generando visualizaciones...\n');

% FIGURA 1: Señales crudas
fig_raw = figure('Position', [100 50 1900 1000], 'Name', 'MMG Signals - Raw Data');
sgtitle('SEÑALES MMG CRUDAS (Sin Filtrar)', 'FontSize', 14, 'FontWeight', 'bold');

for sensor = 1:4
    switch sensor
        case 1, sX=senal1_X; sY=senal1_Y; sZ=senal1_Z;
        case 2, sX=senal2_X; sY=senal2_Y; sZ=senal2_Z;
        case 3, sX=senal3_X; sY=senal3_Y; sZ=senal3_Z;
        case 4, sX=senal4_X; sY=senal4_Y; sZ=senal4_Z;
    end
    subplot(4,3,(sensor-1)*3+1); plot(tiempo,sX,'r','LineWidth',1); grid on; ylabel('Aceleración (g)'); title(sprintf('Sensor %d - Eje X',sensor)); if sensor==4, xlabel('Tiempo (s)'); end
    subplot(4,3,(sensor-1)*3+2); plot(tiempo,sY,'g','LineWidth',1); grid on; ylabel('Aceleración (g)'); title(sprintf('Sensor %d - Eje Y',sensor)); if sensor==4, xlabel('Tiempo (s)'); end
    subplot(4,3,(sensor-1)*3+3); plot(tiempo,sZ,'b','LineWidth',1); grid on; ylabel('Aceleración (g)'); title(sprintf('Sensor %d - Eje Z',sensor)); if sensor==4, xlabel('Tiempo (s)'); end
end

% FIGURA 2: Señales filtradas
fig_filt = figure('Position', [120 70 1900 1000], 'Name', 'MMG Signals - Filtered Data');
sgtitle(sprintf('SEÑALES MMG FILTRADAS (Butterworth %.0f-%.0f Hz)', fc_low, fc_high), 'FontSize', 14, 'FontWeight', 'bold');

for sensor = 1:4
    switch sensor
        case 1, sX=senal1_X_filt; sY=senal1_Y_filt; sZ=senal1_Z_filt;
        case 2, sX=senal2_X_filt; sY=senal2_Y_filt; sZ=senal2_Z_filt;
        case 3, sX=senal3_X_filt; sY=senal3_Y_filt; sZ=senal3_Z_filt;
        case 4, sX=senal4_X_filt; sY=senal4_Y_filt; sZ=senal4_Z_filt;
    end
    subplot(4,3,(sensor-1)*3+1); plot(tiempo,sX,'r','LineWidth',1); grid on; ylabel('Aceleración (g)'); title(sprintf('Sensor %d - Eje X',sensor)); if sensor==4, xlabel('Tiempo (s)'); end
    subplot(4,3,(sensor-1)*3+2); plot(tiempo,sY,'g','LineWidth',1); grid on; ylabel('Aceleración (g)'); title(sprintf('Sensor %d - Eje Y',sensor)); if sensor==4, xlabel('Tiempo (s)'); end
    subplot(4,3,(sensor-1)*3+3); plot(tiempo,sZ,'b','LineWidth',1); grid on; ylabel('Aceleración (g)'); title(sprintf('Sensor %d - Eje Z',sensor)); if sensor==4, xlabel('Tiempo (s)'); end
end

% FIGURA 3: FFT
fig_fft = figure('Position', [140 90 1900 1000], 'Name', 'MMG Frequency Analysis - FFT');
sgtitle('ANÁLISIS ESPECTRAL (FFT) - Todos los Ejes', 'FontSize', 14, 'FontWeight', 'bold');

calcFFT = @(x) abs(fft(x)/N);

for sensor = 1:4
    switch sensor
        case 1, sX=senal1_X_filt; sY=senal1_Y_filt; sZ=senal1_Z_filt; mpf=params.sensor1.freq_Z.MPF; mdf=params.sensor1.freq_Z.MDF;
        case 2, sX=senal2_X_filt; sY=senal2_Y_filt; sZ=senal2_Z_filt; mpf=params.sensor2.freq_Z.MPF; mdf=params.sensor2.freq_Z.MDF;
        case 3, sX=senal3_X_filt; sY=senal3_Y_filt; sZ=senal3_Z_filt; mpf=params.sensor3.freq_Z.MPF; mdf=params.sensor3.freq_Z.MDF;
        case 4, sX=senal4_X_filt; sY=senal4_Y_filt; sZ=senal4_Z_filt; mpf=params.sensor4.freq_Z.MPF; mdf=params.sensor4.freq_Z.MDF;
    end
    PX=calcFFT(sX); PX=PX(1:floor(N/2)+1);
    PY=calcFFT(sY); PY=PY(1:floor(N/2)+1);
    PZ=calcFFT(sZ); PZ=PZ(1:floor(N/2)+1);
    subplot(2,2,sensor);
    plot(f,PX,'r','LineWidth',1.2,'DisplayName','Eje X'); hold on;
    plot(f,PY,'g','LineWidth',1.2,'DisplayName','Eje Y');
    plot(f,PZ,'b','LineWidth',1.5,'DisplayName','Eje Z');
    xline([fc_low fc_high],'--k','LineWidth',1,'HandleVisibility','off');
    xline(mpf,'-.r','LineWidth',1.5,'DisplayName',sprintf('MPF=%.1fHz',mpf));
    xline(mdf,'-.m','LineWidth',1.5,'DisplayName',sprintf('MDF=%.1fHz',mdf));
    grid on; title(sprintf('Sensor %d - Espectro 3 Ejes',sensor),'FontWeight','bold');
    xlabel('Frecuencia (Hz)'); ylabel('Magnitud'); xlim([0 min(100,fs_real/2)]);
    legend('Location','northeast','FontSize',8); hold off;
end

% FIGURA 4: Espectrograma
fig_spec = figure('Position', [160 110 1900 1000], 'Name', 'MMG Time-Frequency - Spectrogram');
sgtitle('ANÁLISIS TIEMPO-FRECUENCIA (Spectrogram) - Todos los Ejes', 'FontSize', 14, 'FontWeight', 'bold');

window_length = round(fs_real * 0.5);
overlap = round(window_length * 0.9);
nfft = 512;

for sensor = 1:4
    switch sensor
        case 1, sX=senal1_X_filt; sY=senal1_Y_filt; sZ=senal1_Z_filt;
        case 2, sX=senal2_X_filt; sY=senal2_Y_filt; sZ=senal2_Z_filt;
        case 3, sX=senal3_X_filt; sY=senal3_Y_filt; sZ=senal3_Z_filt;
        case 4, sX=senal4_X_filt; sY=senal4_Y_filt; sZ=senal4_Z_filt;
    end
    subplot(4,3,(sensor-1)*3+1); spectrogram(sX,hamming(window_length),overlap,nfft,fs_real,'yaxis'); ylim([0 100]); title(sprintf('S%d - Eje X',sensor),'FontSize',9); if sensor==1, ylabel('Frecuencia (Hz)'); end; if sensor==4, xlabel('Tiempo (s)'); end; colorbar off; caxis([-80 -20]);
    subplot(4,3,(sensor-1)*3+2); spectrogram(sY,hamming(window_length),overlap,nfft,fs_real,'yaxis'); ylim([0 100]); title(sprintf('S%d - Eje Y',sensor),'FontSize',9); if sensor==4, xlabel('Tiempo (s)'); end; colorbar off; caxis([-80 -20]);
    subplot(4,3,(sensor-1)*3+3); spectrogram(sZ,hamming(window_length),overlap,nfft,fs_real,'yaxis'); ylim([0 100]); title(sprintf('S%d - Eje Z',sensor),'FontSize',9); if sensor==4, xlabel('Tiempo (s)'); end; colorbar; caxis([-80 -20]);
end

% FIGURA 5: CWT
fprintf('▶ Calculando CWT...\n');
fig_cwt = figure('Position', [180 130 1900 1000], 'Name', 'MMG Wavelet Analysis - CWT');
sgtitle('ANÁLISIS WAVELET (CWT) - Todos los Ejes', 'FontSize', 14, 'FontWeight', 'bold');

for sensor = 1:4
    switch sensor
        case 1, sX=senal1_X_filt; sY=senal1_Y_filt; sZ=senal1_Z_filt;
        case 2, sX=senal2_X_filt; sY=senal2_Y_filt; sZ=senal2_Z_filt;
        case 3, sX=senal3_X_filt; sY=senal3_Y_filt; sZ=senal3_Z_filt;
        case 4, sX=senal4_X_filt; sY=senal4_Y_filt; sZ=senal4_Z_filt;
    end
    subplot(4,3,(sensor-1)*3+1); [wt,freq_cwt]=cwt(sX,fs_real,'amor'); surf(tiempo,freq_cwt,abs(wt),'EdgeColor','none'); view(0,90); axis tight; ylim([5 100]); title(sprintf('S%d - Eje X',sensor),'FontSize',9); if sensor==1, ylabel('Frecuencia (Hz)'); end; if sensor==4, xlabel('Tiempo (s)'); end; colorbar off;
    subplot(4,3,(sensor-1)*3+2); [wt,~]=cwt(sY,fs_real,'amor'); surf(tiempo,freq_cwt,abs(wt),'EdgeColor','none'); view(0,90); axis tight; ylim([5 100]); title(sprintf('S%d - Eje Y',sensor),'FontSize',9); if sensor==4, xlabel('Tiempo (s)'); end; colorbar off;
    subplot(4,3,(sensor-1)*3+3); [wt,~]=cwt(sZ,fs_real,'amor'); surf(tiempo,freq_cwt,abs(wt),'EdgeColor','none'); view(0,90); axis tight; ylim([5 100]); title(sprintf('S%d - Eje Z',sensor),'FontSize',9); if sensor==4, xlabel('Tiempo (s)'); end; colorbar;
end

% FIGURAS 6-8: MDF / RMS / MPF por eje
ejes_nombres = {'X','Y','Z'};
figs_mdf = gobjects(3,1);
figs_rms = gobjects(3,1);
figs_mpf = gobjects(3,1);

for eje = 1:3
    figs_mdf(eje) = figure('Position',[200 150 1400 800],'Name',sprintf('MDF_%s',ejes_nombres{eje}));
    sgtitle(sprintf('EVOLUCIÓN MDF — Eje %s',ejes_nombres{eje}),'FontSize',14,'FontWeight','bold');
    for sensor = 1:4
        subplot(2,2,sensor);
        plot(tiempo_ventanas, MDF_temporal(:,sensor,eje),'b','LineWidth',2); hold on;
        p = polyfit(tiempo_ventanas, MDF_temporal(:,sensor,eje),1);
        plot(tiempo_ventanas, polyval(p,tiempo_ventanas),'r--','LineWidth',2);
        grid on; title(sprintf('Sensor %d - MDF (Eje %s)',sensor,ejes_nombres{eje}));
        xlabel('Tiempo (s)'); ylabel('Frecuencia (Hz)'); hold off;
    end

    figs_rms(eje) = figure('Position',[220 170 1400 800],'Name',sprintf('RMS_%s',ejes_nombres{eje}));
    sgtitle(sprintf('EVOLUCIÓN RMS — Eje %s',ejes_nombres{eje}),'FontSize',14,'FontWeight','bold');
    for sensor = 1:4
        subplot(2,2,sensor);
        plot(tiempo_ventanas, RMS_temporal(:,sensor,eje),'k','LineWidth',2); hold on;
        p = polyfit(tiempo_ventanas, RMS_temporal(:,sensor,eje),1);
        plot(tiempo_ventanas, polyval(p,tiempo_ventanas),'r--','LineWidth',2);
        grid on; title(sprintf('Sensor %d - RMS (Eje %s)',sensor,ejes_nombres{eje}));
        xlabel('Tiempo (s)'); ylabel('Aceleración (g)'); hold off;
    end

    figs_mpf(eje) = figure('Position',[240 190 1400 800],'Name',sprintf('MPF_%s',ejes_nombres{eje}));
    sgtitle(sprintf('EVOLUCIÓN MPF — Eje %s',ejes_nombres{eje}),'FontSize',14,'FontWeight','bold');
    for sensor = 1:4
        subplot(2,2,sensor);
        plot(tiempo_ventanas, MPF_temporal(:,sensor,eje),'g','LineWidth',2); hold on;
        p = polyfit(tiempo_ventanas, MPF_temporal(:,sensor,eje),1);
        plot(tiempo_ventanas, polyval(p,tiempo_ventanas),'r--','LineWidth',2);
        grid on; title(sprintf('Sensor %d - MPF (Eje %s)',sensor,ejes_nombres{eje}));
        xlabel('Tiempo (s)'); ylabel('Frecuencia (Hz)'); hold off;
    end
end

% FIGURA: Symmetry Index (solo bilateral)
if modo_bilateral && exist('SI_temporal','var')
    fig_si = figure('Position',[260 170 800 500],'Name','Symmetry Index Temporal');
    t_si = tiempo_ventanas - tiempo_ventanas(1);
    plot(t_si, SI_temporal,'k','LineWidth',2); hold on;
    yline(0,'--g','Simetría perfecta','LineWidth',1.5);
    yline( 10,'--y','+10%','LineWidth',1); yline(-10,'--y','-10%','LineWidth',1);
    yline( 15,'--r','+15%','LineWidth',1); yline(-15,'--r','-15%','LineWidth',1);
    grid on;
    title(sprintf('Symmetry Index RMS — Global: %.2f%% | SA: %.2f°',SI_global.RMS,SA_global.RMS),'FontWeight','bold');
    xlabel('Tiempo relativo (s)'); ylabel('SI (%)'); ylim([-50 50]); hold off;
end

%% ========== GUARDAR DATOS ==========
fprintf('▶ Guardando datos en: %s\n', carpeta_salida);

datos.info.fecha     = datestr(now);
datos.info.duracion  = duracion;
datos.info.fs        = fs_real;
datos.info.bilateral = modo_bilateral;

datos.tiempo          = tiempo;
datos.tiempo_ventanas = tiempo_ventanas;
datos.MDF_temporal    = MDF_temporal;
datos.MPF_temporal    = MPF_temporal;
datos.RMS_temporal    = RMS_temporal;
datos.pendientes_MDF  = pendientes_MDF;
datos.pendientes_MPF  = pendientes_MPF;
datos.pendientes_RMS  = pendientes_RMS;
datos.params          = params;

if modo_bilateral && exist('SI_global','var')
    datos.SI_global = SI_global;
    datos.SA_global = SA_global;
    if exist('SI_temporal','var'), datos.SI_temporal = SI_temporal; end
end

save(nombre_completo, 'datos');
fprintf('   Datos guardados: %s\n', nombre_completo);

%% ========== GUARDAR FIGURAS ==========
fprintf('▶ Guardando figuras...\n');

% .fig (interactivas)
saveas(fig_raw,  fullfile(carpeta_salida, 'Crudas.fig'));
saveas(fig_filt, fullfile(carpeta_salida, 'Filtradas.fig'));
saveas(fig_fft,  fullfile(carpeta_salida, 'FFT.fig'));

ejes_nombres_fig = {'X','Y','Z'};
for eje = 1:3
    saveas(figs_mdf(eje), fullfile(carpeta_salida, sprintf('MDF_%s.fig', ejes_nombres_fig{eje})));
    saveas(figs_rms(eje), fullfile(carpeta_salida, sprintf('RMS_%s.fig', ejes_nombres_fig{eje})));
    saveas(figs_mpf(eje), fullfile(carpeta_salida, sprintf('MPF_%s.fig', ejes_nombres_fig{eje})));
end

if modo_bilateral && exist('fig_si','var')
    saveas(fig_si, fullfile(carpeta_salida, 'SymmetryIndex.fig'));
end

% .png (figuras pesadas)
exportgraphics(fig_spec, fullfile(carpeta_salida, 'STFT.png'), 'Resolution', 200);
exportgraphics(fig_cwt,  fullfile(carpeta_salida, 'CWT.png'),  'Resolution', 200);

fprintf('   Figuras guardadas correctamente.\n\n');
fprintf('╔══════════════════════════════════════════════════════╗\n');
fprintf('║   PIPELINE COMPLETADO                                ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n\n');

%% ========== FUNCIÓN DETENER ==========
function stopAcquisition(event)
    global stopFlag;
    if strcmp(event.Key, 'space')
        stopFlag = true;
        fprintf('\n Adquisición detenida por el usuario\n');
    end
end