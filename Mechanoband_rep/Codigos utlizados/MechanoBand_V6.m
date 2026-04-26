% ========================================================================
% MECANOMIOGRAFÍA (MMG) — PROCESAMIENTO Y ANÁLISIS
% MechanoBand: Evaluación y caracterización de actividad muscular
% ========================================================================
clear all; close all;

%% ═══════════════════════════════════════════════════════════
%  CONFIGURACIÓN
% ═══════════════════════════════════════════════════════════
fprintf('\n╔══════════════════════════════════════════2═══════════╗\n');
fprintf('║   MECANOMIOGRAFÍA — MechanoBand                      ║\n');
fprintf('║   Caracterización de actividad muscular              ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n\n');

delete(instrfind);

puerto    = 'COM9';
baudrate  = 921600;

fc_low       = 10;
fc_high      = 50;
orden_filtro = 4;

tamano_ventana = 1.0;
overlap_pct    = 0.5;

nombres_musculos = {'Sensor 1','Sensor 2','Sensor 3','Sensor 4'};
ejes_nombre      = {'X','Y','Z'};

modo_bilateral = true;

nombre_archivo = input('Nombre del archivo para guardar datos: ', 's');
if isempty(nombre_archivo)
    nombre_archivo = sprintf('datos_mmg_%s', datestr(now,'yyyymmdd_HHMMSS'));
end
carpeta_salida = nombre_archivo;
if ~exist(carpeta_salida,'dir'), mkdir(carpeta_salida); end
nombre_completo = fullfile(carpeta_salida, [nombre_archivo '.mat']);
fprintf('\n Datos en: %s\n', carpeta_salida);

%% ═══════════════════════════════════════════════════════════
%  CONEXIÓN ESP32
% ═══════════════════════════════════════════════════════════
fprintf('\n▶ Conectando a %s @ %d baud...\n', puerto, baudrate);
s = serialport(puerto, baudrate);
configureTerminator(s, "LF");
flush(s); pause(2);

timeout = tic;
while toc(timeout) < 15
    if s.NumBytesAvailable > 0
        linea = readline(s);
        fprintf('   %s\n', linea);
        if contains(linea,"INICIO"), break; end
    end
    pause(0.1);
end
flush(s); pause(0.5);

%% ═══════════════════════════════════════════════════════════
%  FIGURA TIEMPO REAL
% ═══════════════════════════════════════════════════════════
fig_realtime = figure('Position',[50 50 1900 950],'Name','MMG - Adquisición');
set(fig_realtime,'KeyPressFcn',@(src,ev) stopAcquisition(ev));
global stopFlag; stopFlag = false;

col_eje = {'r','g','b'};
hSens   = cell(4,3);
for s_idx = 1:4
    for e_idx = 1:3
        subplot(4,3,(s_idx-1)*3+e_idx);
        hSens{s_idx,e_idx} = animatedline('Color',col_eje{e_idx},...
            'LineWidth',1.5,'MaximumNumPoints',2000);
        grid on; box on;
        title(sprintf('%s — %s',nombres_musculos{s_idx},ejes_nombre{e_idx}),...
            'FontSize',9,'FontWeight','bold');
        ylabel('g'); ylim([-0.2 0.2]);
        if s_idx==4, xlabel('Tiempo (s)'); end
    end
end
fprintf('\n╔══════════════════════════════════════════════════════╗\n');
fprintf('║   ESPACIO para detener la adquisición                ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════
%  ADQUISICIÓN
% ═══════════════════════════════════════════════════════════
ts_sensor = [];
accel1_X=[]; accel1_Y=[]; accel1_Z=[];
accel2_X=[]; accel2_Y=[]; accel2_Z=[];
accel3_X=[]; accel3_Y=[]; accel3_Z=[];
accel4_X=[]; accel4_Y=[]; accel4_Z=[];
i=1; muestras_perdidas=0;

while ~stopFlag
    try
        if s.NumBytesAvailable > 0
            linea   = readline(s);
            valores = str2double(split(linea,','));
            if length(valores)==13 && all(~isnan(valores))
                ts_sensor(i)  = valores(1);
                accel1_X(i)=valores(2);  accel1_Y(i)=valores(3);  accel1_Z(i)=valores(4);
                accel2_X(i)=valores(5);  accel2_Y(i)=valores(6);  accel2_Z(i)=valores(7);
                accel3_X(i)=valores(8);  accel3_Y(i)=valores(9);  accel3_Z(i)=valores(10);
                accel4_X(i)=valores(11); accel4_Y(i)=valores(12); accel4_Z(i)=valores(13);
                if mod(i,5)==0
                    t_plot = (ts_sensor(i)-ts_sensor(1))/1e6;
                    vals = [accel1_X(i) accel1_Y(i) accel1_Z(i);
                            accel2_X(i) accel2_Y(i) accel2_Z(i);
                            accel3_X(i) accel3_Y(i) accel3_Z(i);
                            accel4_X(i) accel4_Y(i) accel4_Z(i)];
                    for e=1:3
                        for sn=1:4
                            addpoints(hSens{sn,e}, t_plot, vals(sn,e));
                        end
                    end
                    drawnow limitrate;
                end
                i=i+1;
            else
                muestras_perdidas=muestras_perdidas+1;
            end
        end
        if mod(i,50)==0 && ~isempty(ts_sensor)
            t_actual = (ts_sensor(end)-ts_sensor(1))/1e6;
            sgtitle(fig_realtime,...
                sprintf('Tiempo: %.1f s | ESPACIO para detener',t_actual),...
                'FontSize',11,'FontWeight','bold','Color',[0 0.5 0]);
        end
    catch
        muestras_perdidas=muestras_perdidas+1;
    end
end
delete(s);

tiempo   = (ts_sensor - ts_sensor(1)) / 1e6;
duracion = tiempo(end);

%% ═══════════════════════════════════════════════════════════
%  ESTADÍSTICAS ADQUISICIÓN
% ═══════════════════════════════════════════════════════════
dt_sensor = diff(ts_sensor)/1e6;
fs_real   = 1/median(dt_sensor);
jitter_ms = std(dt_sensor)*1000;

fprintf('\n╔══════════════════════════════════════════════════════╗\n');
fprintf('║   ADQUISICIÓN COMPLETADA                             ║\n');
fprintf('╠══════════════════════════════════════════════════════╣\n');
fprintf('║   Duración     : %.2f s\n',  duracion);
fprintf('║   Muestras     : %d\n',       length(tiempo));
fprintf('║   Fs (mediana) : %.2f Hz\n',  fs_real);
fprintf('║   Jitter       : %.3f ms\n',  jitter_ms);
fprintf('║   Perdidas     : %d (%.2f%%)\n', muestras_perdidas,...
        100*muestras_perdidas/(i+muestras_perdidas));
fprintf('╚══════════════════════════════════════════════════════╝\n\n');
if jitter_ms > 1.0
    warning('Jitter > 1 ms. Revisar carga del ESP32.');
end

%% ═══════════════════════════════════════════════════════════
%  PREPROCESAMIENTO
% ═══════════════════════════════════════════════════════════
fprintf('▶ Removiendo DC...\n');

senal1_X=accel1_X-mean(accel1_X); senal1_Y=accel1_Y-mean(accel1_Y); senal1_Z=accel1_Z-mean(accel1_Z);
senal2_X=accel2_X-mean(accel2_X); senal2_Y=accel2_Y-mean(accel2_Y); senal2_Z=accel2_Z-mean(accel2_Z);
senal3_X=accel3_X-mean(accel3_X); senal3_Y=accel3_Y-mean(accel3_Y); senal3_Z=accel3_Z-mean(accel3_Z);
senal4_X=accel4_X-mean(accel4_X); senal4_Y=accel4_Y-mean(accel4_Y); senal4_Z=accel4_Z-mean(accel4_Z);

fprintf('▶ Filtro Butterworth %.0f–%.0f Hz orden %d...\n', fc_low, fc_high, orden_filtro);
if fs_real < 2*fc_high
    fc_high = fs_real/2.5;
    warning('Fs baja, fc_high ajustado a %.1f Hz', fc_high);
end
[b,a] = butter(orden_filtro, [fc_low fc_high]/(fs_real/2), 'bandpass');

senal1_X_f=filtfilt(b,a,senal1_X); senal1_Y_f=filtfilt(b,a,senal1_Y); senal1_Z_f=filtfilt(b,a,senal1_Z);
senal2_X_f=filtfilt(b,a,senal2_X); senal2_Y_f=filtfilt(b,a,senal2_Y); senal2_Z_f=filtfilt(b,a,senal2_Z);
senal3_X_f=filtfilt(b,a,senal3_X); senal3_Y_f=filtfilt(b,a,senal3_Y); senal3_Z_f=filtfilt(b,a,senal3_Z);
senal4_X_f=filtfilt(b,a,senal4_X); senal4_Y_f=filtfilt(b,a,senal4_Y); senal4_Z_f=filtfilt(b,a,senal4_Z);

% Magnitud vectorial + remoción de DC residual
senal1_MAG_f = sqrt(senal1_X_f.^2 + senal1_Y_f.^2 + senal1_Z_f.^2);
senal1_MAG_f = senal1_MAG_f - mean(senal1_MAG_f);
senal2_MAG_f = sqrt(senal2_X_f.^2 + senal2_Y_f.^2 + senal2_Z_f.^2);
senal2_MAG_f = senal2_MAG_f - mean(senal2_MAG_f);
senal3_MAG_f = sqrt(senal3_X_f.^2 + senal3_Y_f.^2 + senal3_Z_f.^2);
senal3_MAG_f = senal3_MAG_f - mean(senal3_MAG_f);
senal4_MAG_f = sqrt(senal4_X_f.^2 + senal4_Y_f.^2 + senal4_Z_f.^2);
senal4_MAG_f = senal4_MAG_f - mean(senal4_MAG_f);

senales_ejes_raw = {senal1_X,   senal1_Y,   senal1_Z;
                    senal2_X,   senal2_Y,   senal2_Z;
                    senal3_X,   senal3_Y,   senal3_Z;
                    senal4_X,   senal4_Y,   senal4_Z};

senales_ejes_f   = {senal1_X_f, senal1_Y_f, senal1_Z_f;
                    senal2_X_f, senal2_Y_f, senal2_Z_f;
                    senal3_X_f, senal3_Y_f, senal3_Z_f;
                    senal4_X_f, senal4_Y_f, senal4_Z_f};

senales_MAG_f    = {senal1_MAG_f; senal2_MAG_f; senal3_MAG_f; senal4_MAG_f};

fprintf('▶ Filtrado completado.\n\n');

%% ═══════════════════════════════════════════════════════════
%  VALIDACIÓN DE SEÑAL ACTIVA
% ═══════════════════════════════════════════════════════════
fprintf('▶ Validando actividad muscular (RMS eje Z)...\n');
umbral = 0.005;
for sn=1:4
    r = rms(senales_ejes_f{sn,3});
    if r < umbral
        warning('S%d (%s): RMS_Z=%.5fg bajo umbral.',sn,nombres_musculos{sn},r);
    else
        fprintf('   S%d %-12s OK  (RMS_Z=%.5fg)\n',sn,nombres_musculos{sn},r);
    end
end
fprintf('\n');

%% ═══════════════════════════════════════════════════════════
%  PARÁMETROS GLOBALES
% ═══════════════════════════════════════════════════════════
fprintf('▶ Calculando parámetros globales...\n');
N_sig = length(senal1_Z_f);
f_eje = fs_real*(0:floor(N_sig/2))/N_sig;

% Por eje — 6 parámetros
for sn=1:4
    for eje=1:3
        sig = senales_ejes_f{sn,eje};
        [Pxx_g, f_g] = periodogram(sig, hamming(N_sig), [], fs_real);
        Pxx_g(1) = 0;  % suprimir DC residual

        % Restringir todos los parámetros frecuenciales a la banda del filtro
        % MPF y MDF sobre todo el espectro incluyen energía residual 0–10 Hz
        % que sesga los valores hacia abajo (MDF puede dar < fc_low)
        idx_banda_g = f_g >= fc_low & f_g <= fc_high;
        Pxx_banda_g = Pxx_g(idx_banda_g);
        f_banda_g   = f_g(idx_banda_g);

        pg(sn,eje).RMS         = rms(sig);
        pg(sn,eje).MPF         = meanfreq(Pxx_banda_g, f_banda_g);
        pg(sn,eje).MDF         = medfreq(Pxx_banda_g,  f_banda_g);
        pg(sn,eje).Entropia    = calcular_entropia(sig, fs_real);
        pg(sn,eje).FreqDom     = freq_dominante(Pxx_g, f_g, fc_low, fc_high);
        idx_b = f_g>=10 & f_g<=25; idx_a = f_g>25 & f_g<=50;
        pg(sn,eje).RatioBandas = sum(Pxx_g(idx_b))/(sum(Pxx_g(idx_a))+1e-12);
    end
end

% Magnitud vectorial — 6 parámetros
for sn=1:4
    sig = senales_MAG_f{sn};
    [Pxx_m, f_m] = periodogram(sig, hamming(N_sig), [], fs_real);
    Pxx_m(1) = 0;  % suprimir DC residual

    idx_banda_m = f_m >= fc_low & f_m <= fc_high;
    Pxx_banda_m = Pxx_m(idx_banda_m);
    f_banda_m   = f_m(idx_banda_m);

    pm(sn).RMS         = rms(sig);
    pm(sn).MPF         = meanfreq(Pxx_banda_m, f_banda_m);
    pm(sn).MDF         = medfreq(Pxx_banda_m,  f_banda_m);
    pm(sn).Entropia    = calcular_entropia(sig, fs_real);
    pm(sn).FreqDom     = freq_dominante(Pxx_m, f_m, fc_low, fc_high);
    idx_b = f_m>=10 & f_m<=25; idx_a = f_m>25 & f_m<=50;
    pm(sn).RatioBandas = sum(Pxx_m(idx_b))/(sum(Pxx_m(idx_a))+1e-12);
end
fprintf('▶ Parámetros globales calculados.\n\n');

%% ═══════════════════════════════════════════════════════════
%  ANÁLISIS POR VENTANAS
% ═══════════════════════════════════════════════════════════
fprintf('▶ Análisis por ventanas...\n');

muestras_v = round(tamano_ventana * fs_real);
paso_v     = round(muestras_v * (1-overlap_pct));
N_total    = length(senal1_Z_f);
inicios    = 1:paso_v:(N_total-muestras_v+1);
nV         = length(inicios);

fprintf('   Ventanas: %d | Muestras/ventana: %d | Overlap: %.0f%%\n\n',...
    nV, muestras_v, overlap_pct*100);

% Por eje: [nV x 4 sensores x 3 ejes]
RMS_eje_t   = zeros(nV,4,3);
MDF_eje_t   = zeros(nV,4,3);
MPF_eje_t   = zeros(nV,4,3);
Entr_t      = zeros(nV,4,3);
FreqDom_t   = zeros(nV,4,3);
Ratio_t     = zeros(nV,4,3);

% Magnitud vectorial: [nV x 4 sensores]
RMS_mag_t     = zeros(nV,4);
MDF_mag_t     = zeros(nV,4);
MPF_mag_t     = zeros(nV,4);
Entr_mag_t    = zeros(nV,4);
FreqDom_mag_t = zeros(nV,4);
Ratio_mag_t   = zeros(nV,4);

tiempo_v = zeros(nV,1);

for v=1:nV
    ini = inicios(v);
    fin = ini + muestras_v - 1;
    tiempo_v(v) = mean(tiempo(ini:fin));

    for sn=1:4
        % ── Por eje ─────────────────────────────────────────
        for eje=1:3
            seg = senales_ejes_f{sn,eje}(ini:fin);
            [Pxx_e, f_e] = periodogram(seg, hamming(muestras_v), [], fs_real);
            Pxx_e(1) = 0;

            idx_banda_e = f_e >= fc_low & f_e <= fc_high;
            Pxx_banda_e = Pxx_e(idx_banda_e);
            f_banda_e   = f_e(idx_banda_e);

            RMS_eje_t(v,sn,eje) = rms(seg);
            MPF_eje_t(v,sn,eje) = meanfreq(Pxx_banda_e, f_banda_e);
            MDF_eje_t(v,sn,eje) = medfreq(Pxx_banda_e,  f_banda_e);
            Entr_t(v,sn,eje)    = calcular_entropia(seg, fs_real);
            FreqDom_t(v,sn,eje) = freq_dominante(Pxx_e, f_e, fc_low, fc_high);
            idx_b = f_e>=10 & f_e<=25; idx_a = f_e>25 & f_e<=50;
            Ratio_t(v,sn,eje)   = sum(Pxx_e(idx_b))/(sum(Pxx_e(idx_a))+1e-12);
        end

        % ── Magnitud vectorial ───────────────────────────────
        seg_m = senales_MAG_f{sn}(ini:fin);
        [Pxx_m, f_m] = periodogram(seg_m, hamming(muestras_v), [], fs_real);
        Pxx_m(1) = 0;

        idx_banda_mv = f_m >= fc_low & f_m <= fc_high;
        Pxx_banda_mv = Pxx_m(idx_banda_mv);
        f_banda_mv   = f_m(idx_banda_mv);

        RMS_mag_t(v,sn)     = rms(seg_m);
        MPF_mag_t(v,sn)     = meanfreq(Pxx_banda_mv, f_banda_mv);
        MDF_mag_t(v,sn)     = medfreq(Pxx_banda_mv,  f_banda_mv);
        Entr_mag_t(v,sn)    = calcular_entropia(seg_m, fs_real);
        FreqDom_mag_t(v,sn) = freq_dominante(Pxx_m, f_m, fc_low, fc_high);
        idx_b = f_m>=10 & f_m<=25; idx_a = f_m>25 & f_m<=50;
        Ratio_mag_t(v,sn)   = sum(Pxx_m(idx_b))/(sum(Pxx_m(idx_a))+1e-12);
    end

    if mod(v,20)==0
        fprintf('   Ventanas: %d/%d\n', v, nV);
    end
end
fprintf('▶ Análisis por ventanas completado.\n\n');

% Pendientes por eje [4 sensores x 3 ejes]
pend_RMS_eje = zeros(4,3); pend_MDF_eje = zeros(4,3);
pend_MPF_eje = zeros(4,3); pend_Entr    = zeros(4,3);
pend_FD      = zeros(4,3); pend_Ratio   = zeros(4,3);

for sn=1:4
    for eje=1:3
        p=polyfit(tiempo_v,RMS_eje_t(:,sn,eje),1); pend_RMS_eje(sn,eje)=p(1);
        p=polyfit(tiempo_v,MDF_eje_t(:,sn,eje),1); pend_MDF_eje(sn,eje)=p(1);
        p=polyfit(tiempo_v,MPF_eje_t(:,sn,eje),1); pend_MPF_eje(sn,eje)=p(1);
        p=polyfit(tiempo_v,Entr_t(:,sn,eje),   1); pend_Entr(sn,eje)   =p(1);
        p=polyfit(tiempo_v,FreqDom_t(:,sn,eje),1); pend_FD(sn,eje)     =p(1);
        p=polyfit(tiempo_v,Ratio_t(:,sn,eje),  1); pend_Ratio(sn,eje)  =p(1);
    end
end

% Pendientes magnitud vectorial [4 sensores]
pend_RMS_mag=zeros(1,4); pend_MDF_mag=zeros(1,4); pend_MPF_mag=zeros(1,4);
pend_Entr_mag=zeros(1,4); pend_FD_mag=zeros(1,4); pend_Ratio_mag=zeros(1,4);
for sn=1:4
    p=polyfit(tiempo_v,RMS_mag_t(:,sn),    1); pend_RMS_mag(sn)    =p(1);
    p=polyfit(tiempo_v,MDF_mag_t(:,sn),    1); pend_MDF_mag(sn)    =p(1);
    p=polyfit(tiempo_v,MPF_mag_t(:,sn),    1); pend_MPF_mag(sn)    =p(1);
    p=polyfit(tiempo_v,Entr_mag_t(:,sn),   1); pend_Entr_mag(sn)   =p(1);
    p=polyfit(tiempo_v,FreqDom_mag_t(:,sn),1); pend_FD_mag(sn)     =p(1);
    p=polyfit(tiempo_v,Ratio_mag_t(:,sn),  1); pend_Ratio_mag(sn)  =p(1);
end

%% ═══════════════════════════════════════════════════════════
%  SYMMETRY INDEX
% ═══════════════════════════════════════════════════════════
if modo_bilateral
    fprintf('▶ Calculando Symmetry Index...\n');
    RMS_izq = (pm(1).RMS + pm(2).RMS)/2;
    RMS_der = (pm(3).RMS + pm(4).RMS)/2;
    SI_global = (RMS_der-RMS_izq)/(0.5*(RMS_der+RMS_izq))*100;
    SA_global = atan((RMS_izq-RMS_der)/(RMS_izq+RMS_der))*(180/pi)*2;
    SI_temporal = zeros(nV,1);
    for v=1:nV
        r_izq=(RMS_mag_t(v,1)+RMS_mag_t(v,2))/2;
        r_der=(RMS_mag_t(v,3)+RMS_mag_t(v,4))/2;
        SI_temporal(v)=(r_der-r_izq)/(0.5*(r_der+r_izq))*100;
    end
    fprintf('   SI=%.2f%% | SA=%.2f°\n\n',SI_global,SA_global);
end

%% ═══════════════════════════════════════════════════════════
%  RESUMEN EN CONSOLA
% ═══════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║   PARÁMETROS GLOBALES — MAGNITUD VECTORIAL                         ║\n');
fprintf('╠══════════╦════════╦════════╦════════╦══════════╦══════════╦═════════╣\n');
fprintf('║ Sensor   ║  RMS   ║  MPF   ║  MDF   ║  FreqDom ║ Entropía ║ Ratio  ║\n');
fprintf('╠══════════╬════════╬════════╬════════╬══════════╬══════════╬═════════╣\n');
for sn=1:4
    fprintf('║ %-8s ║ %.4f ║ %6.2f ║ %6.2f ║  %6.2f  ║  %6.3f  ║ %6.3f ║\n',...
        nombres_musculos{sn},pm(sn).RMS,pm(sn).MPF,pm(sn).MDF,...
        pm(sn).FreqDom,pm(sn).Entropia,pm(sn).RatioBandas);
end
fprintf('╚══════════╩════════╩════════╩════════╩══════════╩══════════╩═════════╝\n\n');

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║   PENDIENTES — EJE Z (referencia fisiológica)               ║\n');
fprintf('╠══════════╦══════════╦══════════╦══════════╦══════════╦══════╣\n');
fprintf('║ Sensor   ║  RMS g/s ║ MDF Hz/s ║ MPF Hz/s ║ Entr /s  ║ Rat  ║\n');
fprintf('╠══════════╬══════════╬══════════╬══════════╬══════════╬══════╣\n');
for sn=1:4
    fprintf('║ %-8s ║ %+8.5f ║ %+8.4f ║ %+8.4f ║ %+8.5f ║%+6.3f║\n',...
        nombres_musculos{sn},pend_RMS_eje(sn,3),pend_MDF_eje(sn,3),...
        pend_MPF_eje(sn,3),pend_Entr(sn,3),pend_Ratio(sn,3));
end
fprintf('╚══════════╩══════════╩══════════╩══════════╩══════════╩══════╝\n\n');

%% ═══════════════════════════════════════════════════════════
%  FUNCIÓN AUXILIAR FIGURAS 3×4 POR EJE
% ═══════════════════════════════════════════════════════════
function fig = figura_por_eje(datos_3D, tiempo_v, nombres_musculos, ...
                               ejes_nombre, col_eje, col_sensor, ...
                               titulo_fig, etiq_eje, nombre_ventana)
    fig = figure('Position',[100 80 1700 900],'Name',nombre_ventana);
    sgtitle(titulo_fig,'FontSize',13,'FontWeight','bold');
    ax = gobjects(3,4);
    for eje=1:3
        for sn=1:4
            ax(eje,sn) = subplot(3,4,(eje-1)*4+sn);
            datos = datos_3D(:,sn,eje);
            plot(tiempo_v, datos,'Color',col_sensor{sn},'LineWidth',1.4);
            hold on;
            p_t = polyfit(tiempo_v, datos, 1);
            plot(tiempo_v, polyval(p_t,tiempo_v),'--',...
                'Color',col_eje{eje},'LineWidth',2.0);
            hold off; grid on;
            if eje==1, title(nombres_musculos{sn},'FontSize',10,'FontWeight','bold'); end
            if sn==1,  ylabel(sprintf('%s — Eje %s',etiq_eje,ejes_nombre{eje}),'FontSize',8); end
            if eje==3, xlabel('Tiempo (s)'); end
            text(0.04,0.91,sprintf('m=%+.4f',p_t(1)),...
                'Units','normalized','FontSize',8,...
                'Color',col_eje{eje},'FontWeight','bold');
        end
        linkaxes(ax(eje,:),'y');
    end
    linkaxes(ax(:),'x');
end

%% ═══════════════════════════════════════════════════════════
%  FIGURAS
% ═══════════════════════════════════════════════════════════
fprintf('▶ Generando figuras...\n');

col_sensor = {[0.2 0.4 0.8],[0.8 0.2 0.2],[0.1 0.7 0.3],[0.8 0.5 0.0]};

% Fig 1: Señales crudas
fig1 = figure('Position',[60 50 1900 1000],'Name','Fig1 - Señales Crudas');
sgtitle('Señales MMG Crudas (DC removido) — 4 Sensores × 3 Ejes',...
    'FontSize',13,'FontWeight','bold');
ax1 = gobjects(4,3);
for sn=1:4
    for eje=1:3
        ax1(sn,eje) = subplot(4,3,(sn-1)*3+eje);
        plot(tiempo,senales_ejes_raw{sn,eje},'Color',col_eje{eje},'LineWidth',0.8);
        grid on;
        title(sprintf('%s — Eje %s',nombres_musculos{sn},ejes_nombre{eje}),...
            'FontSize',9,'FontWeight','bold');
        ylabel('Aceleración (g)');
        if sn==4, xlabel('Tiempo (s)'); end
    end
end
linkaxes(ax1(:),'xy');

% Fig 2: Señales filtradas
fig2 = figure('Position',[80 70 1900 1000],'Name','Fig2 - Señales Filtradas');
sgtitle(sprintf('Señales MMG Filtradas (Butterworth %.0f–%.0f Hz) — 4 Sensores × 3 Ejes',...
    fc_low,fc_high),'FontSize',13,'FontWeight','bold');
ax2 = gobjects(4,3);
for sn=1:4
    for eje=1:3
        ax2(sn,eje) = subplot(4,3,(sn-1)*3+eje);
        plot(tiempo,senales_ejes_f{sn,eje},'Color',col_eje{eje},'LineWidth',1.0);
        grid on;
        title(sprintf('%s — Eje %s',nombres_musculos{sn},ejes_nombre{eje}),...
            'FontSize',9,'FontWeight','bold');
        ylabel('Aceleración (g)');
        if sn==4, xlabel('Tiempo (s)'); end
    end
end
linkaxes(ax2(:),'xy');

% Fig 3: FFT
fig3 = figure('Position',[100 90 1400 800],'Name','Fig3 - FFT');
sgtitle('Análisis Espectral FFT — 3 Ejes por Sensor',...
    'FontSize',13,'FontWeight','bold');
ax3 = gobjects(4,1);
for sn=1:4
    ax3(sn) = subplot(2,2,sn);
    hold on;
    for eje=1:3
        sig = senales_ejes_f{sn,eje};
        Y   = fft(sig)/N_sig;
        P   = abs(Y(1:floor(N_sig/2)+1));
        plot(f_eje,P,'Color',col_eje{eje},'LineWidth',1.3,...
            'DisplayName',sprintf('Eje %s',ejes_nombre{eje}));
    end
    xline(pg(sn,3).MPF,'-.','Color',[0.7 0 0],'LineWidth',1.5,...
        'Label',sprintf('MPF=%.1fHz',pg(sn,3).MPF),'FontSize',8);
    xline(pg(sn,3).MDF,'--','Color',[0.4 0 0.8],'LineWidth',1.5,...
        'Label',sprintf('MDF=%.1fHz',pg(sn,3).MDF),'FontSize',8);
    xline(pg(sn,3).FreqDom,':','Color',[0 0.6 0],'LineWidth',1.5,...
        'Label',sprintf('Fd=%.1fHz',pg(sn,3).FreqDom),'FontSize',8);
    xline([fc_low fc_high],'--k','LineWidth',0.8,'HandleVisibility','off');
    hold off;
    xlim([0 80]); grid on;
    title(sprintf('%s | Entr_Z=%.3f | Ratio_Z=%.2f',...
        nombres_musculos{sn},pg(sn,3).Entropia,pg(sn,3).RatioBandas),...
        'FontSize',9,'FontWeight','bold');
    xlabel('Frecuencia (Hz)'); ylabel('Magnitud');
    legend('Location','northeast','FontSize',8);
end
linkaxes(ax3,'xy');

% Fig 4: Espectrograma
fig4 = figure('Position',[120 110 1900 1000],'Name','Fig4 - Espectrograma');
sgtitle('Espectrograma STFT — 4 Sensores × 3 Ejes','FontSize',13,'FontWeight','bold');
win_st=round(fs_real*0.5); ovl_st=round(win_st*0.9); nfft_st=512;
ax4 = gobjects(4,3);
for sn=1:4
    for eje=1:3
        ax4(sn,eje) = subplot(4,3,(sn-1)*3+eje);
        spectrogram(senales_ejes_f{sn,eje},hamming(win_st),ovl_st,...
            nfft_st,fs_real,'yaxis');
        ylim([0 80]);
        title(sprintf('%s — %s',nombres_musculos{sn},ejes_nombre{eje}),...
            'FontSize',9,'FontWeight','bold');
        if sn==4, xlabel('Tiempo (s)'); end
        ylabel('Frec. (Hz)'); colorbar off; caxis([-80 -20]);
    end
end
cb4 = colorbar('eastoutside'); cb4.Label.String='Potencia (dB)';
linkaxes(ax4(:),'xy');

% Fig 5: CWT
fprintf('▶ Calculando CWT...\n');
fig5 = figure('Position',[140 130 1900 1000],'Name','Fig5 - CWT');
sgtitle('Análisis Wavelet CWT (Morlet) — 4 Sensores × 3 Ejes',...
    'FontSize',13,'FontWeight','bold');
ax5 = gobjects(4,3);
for sn=1:4
    for eje=1:3
        ax5(sn,eje) = subplot(4,3,(sn-1)*3+eje);
        [wt,fq] = cwt(senales_ejes_f{sn,eje},fs_real,'amor');
        surf(tiempo,fq,abs(wt),'EdgeColor','none');
        view(0,90); axis tight; ylim([5 80]);
        title(sprintf('%s — %s',nombres_musculos{sn},ejes_nombre{eje}),...
            'FontSize',9,'FontWeight','bold');
        if sn==4, xlabel('Tiempo (s)'); end
        ylabel('Frec. (Hz)'); colorbar off;
    end
end
cb5 = colorbar('eastoutside'); cb5.Label.String='Amplitud wavelet';
fprintf('▶ CWT completado.\n\n');

% Figs 6–11: parámetros por eje
fig6  = figura_por_eje(RMS_eje_t, tiempo_v, nombres_musculos, ejes_nombre,...
    col_eje, col_sensor, 'Evolución RMS por Eje (50% overlap)', 'RMS (g)', 'Fig6 - RMS');
fig7  = figura_por_eje(MDF_eje_t, tiempo_v, nombres_musculos, ejes_nombre,...
    col_eje, col_sensor, 'Evolución MDF por Eje (50% overlap)', 'MDF (Hz)', 'Fig7 - MDF');
fig8  = figura_por_eje(MPF_eje_t, tiempo_v, nombres_musculos, ejes_nombre,...
    col_eje, col_sensor, 'Evolución MPF por Eje (50% overlap)', 'MPF (Hz)', 'Fig8 - MPF');
fig9  = figura_por_eje(Entr_t,    tiempo_v, nombres_musculos, ejes_nombre,...
    col_eje, col_sensor, 'Evolución Entropía Espectral por Eje', 'Entropía (bits)', 'Fig9 - Entropía');
fig10 = figura_por_eje(FreqDom_t, tiempo_v, nombres_musculos, ejes_nombre,...
    col_eje, col_sensor, 'Evolución Frecuencia Dominante por Eje', 'Freq Dom (Hz)', 'Fig10 - FreqDom');
fig11 = figura_por_eje(Ratio_t,   tiempo_v, nombres_musculos, ejes_nombre,...
    col_eje, col_sensor, 'Evolución Ratio de Bandas (10-25/25-50 Hz)', 'Ratio B/A', 'Fig11 - Ratio');

% Fig 12: Resumen magnitud vectorial
fig12 = figure('Position',[160 150 1900 1000],'Name','Fig12 - Resumen Magnitud Vectorial');
sgtitle('Evolución Temporal — 6 Parámetros sobre Magnitud Vectorial (50% overlap)',...
    'FontSize',13,'FontWeight','bold');
params_mag_t = {RMS_mag_t,MDF_mag_t,MPF_mag_t,Entr_mag_t,FreqDom_mag_t,Ratio_mag_t};
etiq_mag     = {'RMS (g)','MDF (Hz)','MPF (Hz)','Entropía (bits)','FreqDom (Hz)','Ratio B/A'};
col_param    = {[0 0 0],[0.1 0.3 0.9],[0.2 0.6 0.8],[0.8 0.4 0],[0.1 0.7 0.3],[0.6 0.1 0.6]};
ax12 = gobjects(6,4);
for par=1:6
    for sn=1:4
        ax12(par,sn) = subplot(6,4,(par-1)*4+sn);
        datos = params_mag_t{par}(:,sn);
        plot(tiempo_v,datos,'Color',col_sensor{sn},'LineWidth',1.3);
        hold on;
        p_t = polyfit(tiempo_v,datos,1);
        plot(tiempo_v,polyval(p_t,tiempo_v),'--','Color',col_param{par},'LineWidth',1.8);
        hold off; grid on;
        if par==1, title(nombres_musculos{sn},'FontSize',9,'FontWeight','bold'); end
        if sn==1,  ylabel(etiq_mag{par},'FontSize',7); end
        if par==6, xlabel('Tiempo (s)'); end
        text(0.03,0.88,sprintf('m=%+.4f',p_t(1)),...
            'Units','normalized','FontSize',7,'Color',col_param{par},'FontWeight','bold');
    end
    linkaxes(ax12(par,:),'y');
end
linkaxes(ax12(:),'x');

% Fig 13: Symmetry Index
if modo_bilateral && exist('SI_temporal','var')
    fig13 = figure('Position',[180 170 900 500],'Name','Fig13 - Symmetry Index');
    fill([tiempo_v(1) tiempo_v(end) tiempo_v(end) tiempo_v(1)],...
         [-10 -10 10 10],[0.9 1 0.9],'FaceAlpha',0.3,'EdgeColor','none');
    hold on;
    plot(tiempo_v,SI_temporal,'k','LineWidth',2);
    yline(0,'--g','Simetría perfecta','LineWidth',1.5);
    yline( 10,'--','Color',[0.9 0.7 0],'LineWidth',1,'Label','+10%');
    yline(-10,'--','Color',[0.9 0.7 0],'LineWidth',1,'Label','-10%');
    yline( 15,'--r','LineWidth',1,'Label','+15%');
    yline(-15,'--r','LineWidth',1,'Label','-15%');
    hold off; grid on;
    title(sprintf('Symmetry Index — SI=%.2f%% | SA=%.2f°',...
        SI_global,SA_global),'FontWeight','bold');
    xlabel('Tiempo (s)'); ylabel('SI (%)'); ylim([-40 40]);
end

%% ═══════════════════════════════════════════════════════════
%  GUARDAR DATOS

fprintf('▶ Guardando datos...\n');
datos = struct(); datos.info = struct();

datos.info.fecha     = datestr(now);
datos.info.duracion  = duracion;
datos.info.fs        = fs_real;
datos.info.jitter_ms = jitter_ms;
datos.info.fc_low    = fc_low;
datos.info.fc_high   = fc_high;
datos.info.musculos  = nombres_musculos;
datos.info.overlap   = overlap_pct;

datos.tiempo          = tiempo;
datos.ts_sensor       = ts_sensor;
datos.tiempo_ventanas = tiempo_v;

datos.RMS_eje_t = RMS_eje_t; datos.MDF_eje_t = MDF_eje_t; datos.MPF_eje_t = MPF_eje_t;
datos.Entr_t    = Entr_t;    datos.FreqDom_t = FreqDom_t;  datos.Ratio_t   = Ratio_t;

datos.RMS_mag_t = RMS_mag_t; datos.MDF_mag_t = MDF_mag_t; datos.MPF_mag_t = MPF_mag_t;
datos.Entr_mag_t = Entr_mag_t; datos.FreqDom_mag_t = FreqDom_mag_t; datos.Ratio_mag_t = Ratio_mag_t;

datos.pend_RMS_eje=pend_RMS_eje; datos.pend_RMS_mag=pend_RMS_mag;
datos.pend_MDF_eje=pend_MDF_eje; datos.pend_MDF_mag=pend_MDF_mag;
datos.pend_MPF_eje=pend_MPF_eje; datos.pend_MPF_mag=pend_MPF_mag;
datos.pend_Entr=pend_Entr;       datos.pend_Entr_mag=pend_Entr_mag;
datos.pend_FD=pend_FD;           datos.pend_FD_mag=pend_FD_mag;
datos.pend_Ratio=pend_Ratio;     datos.pend_Ratio_mag=pend_Ratio_mag;

datos.pg = pg;
datos.pm = pm;

if modo_bilateral && exist('SI_global','var')
    datos.SI_global=SI_global; datos.SA_global=SA_global; datos.SI_temporal=SI_temporal;
end

save(nombre_completo,'datos');
fprintf('   Guardado: %s\n', nombre_completo);

%% ═══════════════════════════════════════════════════════════
%  GUARDAR FIGURAS

fprintf('▶ Guardando figuras...\n');

saveas(fig1,  fullfile(carpeta_salida,'Fig01_Crudas.fig'));
saveas(fig2,  fullfile(carpeta_salida,'Fig02_Filtradas.fig'));
saveas(fig3,  fullfile(carpeta_salida,'Fig03_FFT.fig'));
saveas(fig6,  fullfile(carpeta_salida,'Fig06_RMS_eje.fig'));
saveas(fig7,  fullfile(carpeta_salida,'Fig07_MDF_eje.fig'));
saveas(fig8,  fullfile(carpeta_salida,'Fig08_MPF_eje.fig'));
saveas(fig9,  fullfile(carpeta_salida,'Fig09_Entropia_eje.fig'));
saveas(fig10, fullfile(carpeta_salida,'Fig10_FreqDom_eje.fig'));
saveas(fig11, fullfile(carpeta_salida,'Fig11_Ratio_eje.fig'));
saveas(fig12, fullfile(carpeta_salida,'Fig12_Resumen_Magnitud.fig'));

exportgraphics(fig4, fullfile(carpeta_salida,'Fig04_Espectrograma.png'),'Resolution',200);
exportgraphics(fig5, fullfile(carpeta_salida,'Fig05_CWT.png'),          'Resolution',200);

if modo_bilateral && exist('fig13','var')
    saveas(fig13, fullfile(carpeta_salida,'Fig13_SymmetryIndex.fig'));
end

fprintf('\n╔══════════════════════════════════════════════════════╗\n');
fprintf('║   PIPELINE COMPLETADO — MechanoBand v5.2             ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════
%  FUNCIONES LOCALES

function fd = freq_dominante(Pxx, f, fc_low, fc_high)
    idx_banda = f >= fc_low & f <= fc_high;
    if ~any(idx_banda), fd = NaN; return; end
    [~, idx] = max(Pxx(idx_banda));
    f_banda  = f(idx_banda);
    fd       = f_banda(idx);
end

function H = calcular_entropia(senal, fs)
% Entropía espectral de Shannon (bits).
    N   = length(senal);
    x_n = senal / (std(senal) + 1e-12);
    Y   = fft(x_n);
    P   = abs(Y(1:floor(N/2)+1)).^2 / N;
    P_n = P / (sum(P) + 1e-12);
    H   = -sum(P_n .* log2(P_n + 1e-12));
end

function stopAcquisition(event)
    global stopFlag;
    if strcmp(event.Key,'space')
        stopFlag = true;
        fprintf('\n▶ Adquisición detenida por el usuario.\n');
    end
end

% 
% mu_ch    = mean(chanel_multi);
% sigma_ch = std(chanel_multi);
% canaln   = (chanel_multi - mu_ch) / sigma_ch;
% canaln2  = canaln .^ 2;
% Suavizado gaussiano
% win_gauss    = round(ventana_suav_s * fs_real);
% canaln2_suav = smoothdata(canaln2, 'gaussian', win_gauss);
% Figura de verificación
% fig_seg = figure('Position', [100 100 1400 400], 'Name', 'Envolvente');
% plot(tiempo, canaln2_suav, 'b', 'LineWidth', 1.2); hold on;
