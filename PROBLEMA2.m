fprintf("\n______________________________________________\n");
warning('off', 'all');
%    Datos suposiscion
global escala;
global monedas;
global FR;
monedas = [1 17; 10 21; 50 25; 100 27; 100 23.5; 500 26];

USAR = 1;
nombre_archivos   = ["1.png" "2.jpeg"]; 
escala_archivo   = [0.1463 0.088]; % mm/pixel

escala = escala_archivo(USAR); 
nombre_archivo = nombre_archivos(USAR);

FR = 6; %Formato de Resultados
%{
1 - Mostrar Proceso Global y Cantidad 
2 - Mostrar todos los segmentos originales
3 - Mostrar todos los segmentos finales
4 - Mostrar los perimetros de segmentos
5 - Mostrar los diametros de segmentos
6 - Mostrar las monedas y monto de segmentos
%}

fprintf("\n Valor y manaño de monedas Chilenas:\n")
for m = 1:length(monedas(:,1))
    fprintf("\nMoneda de $%i : %.2fmm",monedas(m,1),monedas(m,2));
end
fprintf("\n______________________________________________\n");


%% CONFIGURACIONES ==========================================================
%    Configuraciones globales
configuracion.global.ajuste_contraste.in     = [0.3 1];%[0 .7]; %%[0.3 1];
configuracion.global.ajuste_contraste.out    = [0 1];
configuracion.global.ajuste_contraste.gamma  = 1;%10; %% 1

configuracion.global.filtrar_ruido.size      = 8;%28; %% 8

configuracion.global.morfologizar.tecnica    = ["erosion" "dilatacion"];
configuracion.global.morfologizar.shape      = ["disk" "disk"];
configuracion.global.morfologizar.size       = [40,20];%[65,25]; %% [40,20];

configuracion.global.boundingboxear.area_min = 0.001;
configuracion.global.boundingboxear.factor_a = 1.1;%2;   %% 1.1

%    Configuraciones segmentos
configuracion.segmentos.ajuste_contraste.in     = [0 1];%[0 .7]; %% [0 1];
configuracion.segmentos.ajuste_contraste.out    = [0 1]; 
configuracion.segmentos.ajuste_contraste.gamma  = 1;%10;    %% 1

configuracion.segmentos.filtrar_ruido.size      = 1;%5;    %% 1

configuracion.segmentos.medir_diametros.radio_min    = 10;%50;   %%% 10
configuracion.segmentos.medir_diametros.sensibilidad = 0.88;%.95;   %% 0.88;

%% MAIN======================================================================

%    importar imagen
imagen = importar_imagen(nombre_archivo);

%    Procesar imagen global
config        = configuracion.global;
tipo          = true;
imag_in       = imagen.global;
imagen.global = procesar_imagen(imag_in,config,tipo);

%   Crear segmentos
imagen_in = imagen.global;
imagen.segmentos.proceso.original = segmentar(imagen_in);

%    Procesar imagen segmentos
config    = configuracion.segmentos;
tipo      = false;
originales = imagen.segmentos.proceso.original;
cantidad_objetos = imagen.global.informacion.cantidad_objetos;
imagen.segmentos = procesamiento_segmentos(originales,cantidad_objetos,config,tipo);

%   Determinar diametros
config = config.medir_diametros;
imagen = medir_diametros(imagen,cantidad_objetos,config);

%   Determinar monedas y calcular montos
imagen = money(imagen);

%Presentar resultados
mostrar_resultados(imagen);

%% PROCESAR IMAGEN===========================================================
function imagen_salida = procesar_imagen(imagen,configs,tipo)

im_uso = imagen.proceso.original;

%pasar a escala de grises
im_uso = escala_grises(im_uso);
imagen.proceso.gris = im_uso;

%arreglo de contraste
config = configs.ajuste_contraste;
im_uso = arreglo_contraste(im_uso,config);
imagen.proceso.ajustada = im_uso;

%binarizacion
im_uso = imcomplement(imbinarize(im_uso,"global"));
imagen.proceso.binarizada = im_uso;

%Reduccion de ruido
config = configs.filtrar_ruido;
im_uso = filtrar_ruido(im_uso,config);
imagen.proceso.filtrada = im_uso;

if tipo == true
    %morfologizar
    config = configs.morfologizar;
    imagen.proceso.morfologizada = morfologizar(im_uso,config);

    %crear un bounding box
    config = configs.boundingboxear;
    imagen = crear_boundingbox(imagen,config);
end

imagen_salida = imagen;
end

%% FUNCIONES=================================================================

%F.     Leer Imgagen ..................................................
function imagen = importar_imagen(nombre_archivo)
imagen.global.informacion.nombre = nombre_archivo;
imagen.global.proceso.original = imread(nombre_archivo);
end

%F.     Pasar a escala de grises-------------------------------------------
function imagen_out = escala_grises(imagen_in)
imagen_out = rgb2gray(imagen_in);
end

%F.     Arreglo de contraste-----------------------------------------------
function imagen_out = arreglo_contraste(imagen_in,config)
in = config.in;
out = config.out;
gamma = config.gamma;
imagen_out = imadjust(imagen_in,in,out,gamma);
end

%F.     Reduccion de ruido-------------------------------------------------

function imagen_out = filtrar_ruido(imagen_in,config)
d = config.size;
imagen_out=medfilt2(imagen_in,[d d]);
end

%F.      Morfologizacion---------------------------------------------------
function imagen_out = morfologizar(imagen_in,config)
imagen_use = imagen_in;
for n = 1:1:2
    tecnica = config.tecnica(n);
    shape   = config.shape(n);
    size    = config.size(n);
    se      = strel(shape, size);
    if tecnica == "apertura"
        imagen_use = imopen(imagen_use,se);
    elseif tecnica == "clausura"
        imagen_use = imclose(imagen_use,se);
    elseif tecnica == "dilatacion"
        imagen_use = imdilate(imagen_use,se);
    elseif tecnica == "erosion"
        imagen_use = imerode(imagen_use,se);
    end
end
imagen_out = imagen_use;
end

%F.     Creacion del boundingbox-------------------------------------------
function imagen= crear_boundingbox(imagen,config)
propiedades     = regionprops(imagen.proceso.morfologizada,'BoundingBox', 'Area');
area            = numel(imagen.proceso.original(:,:,1));
area_minima     = config.area_min * area;
factor_a        = config.factor_a;

imagen_dibujada_normal= imagen.proceso.original;
imagen_dibujada_amplif= imagen.proceso.original;

contador = 0;
for i = 1:length(propiedades)

    area_caja  = propiedades(i).Area;
    coord_caja = propiedades(i).BoundingBox;

    if area_caja >= area_minima
        contador = contador + 1;

        imagen_dibujada_normal = encajar(imagen_dibujada_normal,coord_caja,'r');
        cajas_normal(contador,:) = coord_caja;

        coord_caja_a = amplificar_caja(coord_caja,factor_a);

        imagen_dibujada_amplif = encajar(imagen_dibujada_amplif,coord_caja_a,'a');
        cajas_amplif(contador,:) = coord_caja_a;
    end
end

if contador == 0
    fprintf("No se encontraron objetos\n");
else
    imagen.proceso.encajada.normal             = imagen_dibujada_normal;
    imagen.proceso.encajada.amplificada        = imagen_dibujada_amplif;

    imagen.informacion.coord_cajas.normal      = cajas_normal;
    imagen.informacion.coord_cajas.amplificada = cajas_amplif;
end
    imagen.informacion.cantidad_objetos        = contador;
end

%F.     Encajar
function imagen_salida = encajar(img,box,color)

if size(img, 3) == 1
    img = repmat(img, 1, 1, 3);
end
imagen_salida = img;

if color == 'r'
    rgb = [255 0 0];
elseif color == 'a'
    rgb = [0 0 255];
end

lineWidth = 4;
for i = 1:size(box, 1)
    rect = box(i, :);
    x = round(rect(1));
    y = round(rect(2));
    w = round(rect(3));
    h = round(rect(4));
    for l = 0:lineWidth-1
        imagen_salida = drawLine(imagen_salida, x, y+l, x+w, y+l, rgb);
        imagen_salida = drawLine(imagen_salida, x, y+h-l, x+w, y+h-l, rgb);
        imagen_salida = drawLine(imagen_salida, x+l, y, x+l, y+h, rgb);
        imagen_salida = drawLine(imagen_salida, x+w-l, y, x+w-l, y+h, rgb);
    end
end
end

%F.     Dibujar lineas
function img = drawLine(img, x1, y1, x2, y2, color)
[h, w, ~] = size(img);
x1 = max(1, min(x1, w));
x2 = max(1, min(x2, w));
y1 = max(1, min(y1, h));
y2 = max(1, min(y2, h));
if x1 == x2
    ys = min(y1, y2):max(y1, y2);
    for y = ys
        img(y, x1, :) = color;
    end
elseif y1 == y2
    xs = min(x1, x2):max(x1, x2);
    for x = xs
        img(y1, x, :) = color;
    end
end
end

%F.     Amplificar Cajas
function coord_out = amplificar_caja(coord_in, factor)
x1 = coord_in(1);
y1 = coord_in(2);
ancho = coord_in(3);
alto = coord_in(4);

centro_x = x1 + (ancho/2);
centro_y = y1 + (alto/2);

factor_lineal = sqrt(1 + factor);
nuevo_ancho = ancho * factor_lineal;
nuevo_alto  = alto  * factor_lineal;

x1_nuevo = centro_x - (nuevo_ancho / 2);
y1_nuevo = centro_y - (nuevo_alto  / 2);

coord_out = [x1_nuevo, y1_nuevo, nuevo_ancho, nuevo_alto];
end

%F.     Segmentar imagen---------------------------------------------------
function segmentos = segmentar(imagen)

imagen_original = imagen.proceso.original;
cajas_recorte   = imagen.informacion.coord_cajas.amplificada;
num_segmentos = imagen.informacion.cantidad_objetos;

segmentos = cell(num_segmentos, 1);
for i = 1:num_segmentos
    x = cajas_recorte(i, 1);
    y = cajas_recorte(i, 2);
    ancho = cajas_recorte(i, 3);
    alto  = cajas_recorte(i, 4);
    x1 = floor(x) + 1;
    y1 = floor(y) + 1;
    x2 = ceil(x + ancho);
    y2 = ceil(y + alto);
    x1 = max(x1, 1);
    y1 = max(y1, 1);
    x2 = min(x2, size(imagen_original, 2));
    y2 = min(y2, size(imagen_original, 1));

    imagen_recorte = imagen_original(y1:y2, x1:x2, :);
    segmentos{i} = imagen_recorte;
end
end

%F.     Procesamiento de segmentos-----------------------------------------
function segmentos = procesamiento_segmentos(originales,cantidad_objetos,config,tipo)

for j = 1:cantidad_objetos
    segm_2.proceso.original = originales{j};
    segm_2 = procesar_imagen(segm_2,config,tipo);
    grises{j}      = segm_2.proceso.gris;
    ajustadas{j}   = segm_2.proceso.ajustada;
    binarizadas{j} = segm_2.proceso.binarizada;
    filtradas{j}   = segm_2.proceso.filtrada;
end

segmentos.proceso.original   = originales;
segmentos.proceso.gris       = grises;
segmentos.proceso.ajustada   = ajustadas;
segmentos.proceso.binarizada = binarizadas;
segmentos.proceso.filtrada   = filtradas;
end

%F.     Determinar diametros-----------------------------------------------
function imagen = medir_diametros(imagen,cantidad_objetos,config)
global escala;
global FR;

dimensiones = size(imagen.global.proceso.binarizada);
radio_min = config.radio_min;
sensibilidad = config.sensibilidad;

imagenes_bin = imagen.segmentos.proceso.filtrada;
imagenes_org = imagen.segmentos.proceso.original;

for i = 1:cantidad_objetos

    dimension_segmento = size(imagenes_bin{i});
    radio_max          = max(dimension_segmento);

    % transformada de Hough
    [centers, radios, metricas] = imfindcircles(imagenes_bin{i}, [radio_min, radio_max],'ObjectPolarity', 'bright', 'Sensitivity', sensibilidad);

    if isempty(radios)
        diametros{i}  = 0; %#ok<*AGROW,NASGU>
        fprintf("\n\nNo hay na' en el segmento %i !!!\n\n",i);
        return;
    end

    [~, idx_max] = max(metricas);
    diametros{i} = 2 * radios(idx_max); %en pixeles
    diametros{i} = diametros{i}*escala; %en mm

    if FR == 5
        imagenes_diametros{i} = escribir_encima(diametros{i},imagenes_org{i},'mm');
        fprintf("Escribiendo y mostrando");
        imagen.segmentos.proceso.diametros{i} = imagenes_diametros{i};

    elseif FR == 4
        circulo = [[centers(idx_max,1) centers(idx_max,2)], radios(idx_max)];
        imagenes_perimetros{i} = insertShape(imagenes_org{i},"circle",circulo,'Color', 'red', 'LineWidth', 3);

        %imagen_bin_uint8 = uint8(imagenes_bin{i}) * 255;
        %imagen_rgb = cat(3, imagen_bin_uint8, imagen_bin_uint8, imagen_bin_uint8);
        %imagenes_perimetros{i} = insertShape(imagen_rgb,"circle",circulo,'Color', 'red', 'LineWidth', 3);

        imagen.segmentos.proceso.perimetros{i} = imagenes_perimetros{i};
    end
fprintf(" diametro de moneda %i:  %.2fmm\n",i,round(diametros{i},2));

end
imagen.global.informacion.dimension = dimensiones;
imagen.segmentos.informacion.diametros = diametros;
fprintf("\n______________________________________________\n");
end

%F.     Escribir en imagen-------------------------------------------------
function imagen_out = escribir_encima(valor,imagen_in,unit)

tamano  = size(imagen_in);
pos_x = round(tamano(1)/4);
pos_y = round(tamano(2)/4);

fig = figure('Visible', 'off', 'Position', [100 100 size(imagen_in,2) size(imagen_in,1)]);
imshow(imagen_in, 'Border', 'tight');
hold on;
if unit == "$"
    texto = sprintf("$%i",round(valor));
    FontSize =  0.1 * tamano(1);
else
    texto = sprintf("%.2fmm",round(valor,2));
    FontSize = 0.1 * tamano(1);
end

text(pos_x,pos_y,texto,'Color','white','FontSize',FontSize,'FontWeight','bold','BackgroundColor','black','Margin', 2);
hold off;
frame = getframe(gca);
imagen_out = frame.cdata;

close(fig);
end

%F.     Determinar monedas y calcular montos-------------------------------
function imagen = money(imagen)
global monedas;
global FR;

imagenes_org = imagen.segmentos.proceso.original;
diametros = imagen.segmentos.informacion.diametros;
montos = zeros(length(diametros), 1);
monto = 0;

for i = 1:length(diametros)
    diferencias = abs(monedas(:,2) - diametros{i});
    [~, idx_min] = min(diferencias);
    montos(i) = monedas(idx_min, 1);
    if FR == 6
        imagenes_montos{i} = escribir_encima(montos(i), imagenes_org{i}, '$');
        fprintf("Escribiendo y mostrando");
        imagen.segmentos.proceso.montos{i} = imagenes_montos{i};
    end
    fprintf(" monto de moneda %i:     $%i\n",i,montos(i));
    monto = monto + montos(i);
end
fprintf("______________________________________________\n");

% LOS DATOS DE MONEDAS CORRECTAS SOLO SE USAN PARA MEDIR ERROR 
%Evaluacion de asertibidad==================================================================================
monedas_correctas = [10 21;100 23;100 23;10 21;100 23;10 21;10 21;100 23;50 25;50 25;50 25;50 25;100 23;50 25;50 25;50 25;50 25;100 23];
monedas_leidas    = cell2mat(diametros);
s = 0;
for m = 1:1:9
    error(m) = abs(monedas_correctas(m,2) - monedas_leidas(m));
    fprintf(" Error de moneda %i : %.3fmm\n",m,error(m));
    s = s + error(m);
end
E = s/m;

%Evaluacion de asertibidad==================================================================================
fprintf("\n______________________________________________\n");
fprintf("     Monto total determinado  :  $%i\n",monto);
fprintf("     Error de medicion        :  %.2fmm",E);
fprintf("\n______________________________________________\n");
imagen.global.informacion.monto = monto;
imagen.segmentos.informacion.montos = montos;
hold off;
end

%% MOSTRAR RESULTADOS========================================================

function mostrar_resultados(resultado)
global FR;

if FR == 1 %ProcesoGlobalCantidad
    fprintf("\n\n--->FORMATO DE RESPUESTA %i:  Proceso Global Cantidad\n\n",FR);
    imagen = resultado.global.proceso;
    inform = resultado.global.informacion;

    texto   = sprintf("Cantidad de monedas: %d \n", inform.cantidad_objetos);
    mostrar = {imagen.original,
        imagen.gris,
        imagen.ajustada,
        imagen.binarizada,
        imagen.filtrada,
        imagen.morfologizada,
        imagen.encajada.normal,
        imagen.encajada.amplificada
        };
    montage(mostrar,'Size',[4 2]);
    title (texto);

elseif FR == 2 %Mostrar todos los segmentos originales
    fprintf("\n\n--->FORMATO DE RESPUESTA %i:  Mostrar todos los segmentos originales\n\n",FR);
    mostrar = resultado.segmentos.proceso.original;
    inform = resultado.global.informacion;
    texto   = sprintf("Cantidad de monedas: %d \n", inform.cantidad_objetos);
    dim = ceil(sqrt(inform.cantidad_objetos));
    montage(mostrar,'Size',[dim dim]);
    title (texto);

elseif FR == 3 %Mostrar todos los segmentos finales
    fprintf("\n\n--->FORMATO DE RESPUESTA %i:  Mostrar todos los segmentos finales\n\n",FR);
    mostrar = resultado.segmentos.proceso.filtrada;
    inform = resultado.global.informacion;
    texto   = sprintf("Cantidad de monedas: %d \n", inform.cantidad_objetos);
    dim = ceil(sqrt(inform.cantidad_objetos));
    montage(mostrar,'Size',[dim dim]);
    title (texto);

elseif FR == 5 %Mostrar los diametros de segmentos
    fprintf("\n\n--->FORMATO DE RESPUESTA %i:  Mostrar los diametros de segmentos\n\n",FR);
    mostrar = resultado.segmentos.proceso.diametros;
    inform = resultado.global.informacion;
    texto   = sprintf("Cantidad de monedas: %d \n", inform.cantidad_objetos);
    dim = ceil(sqrt(inform.cantidad_objetos));
    montage(mostrar,'Size',[dim dim]);
    title (texto);

elseif FR == 6 %Mostrar las monedas y monto de segmentos
    fprintf("\n\n--->FORMATO DE RESPUESTA %i:  Mostrar las monedas y monto de segmentos\n\n",FR);
    mostrar = resultado.segmentos.proceso.montos;
    inform = resultado.global.informacion;
    texto   = sprintf("Cantidad de monedas: %d \n Monto total: $%d \n", inform.cantidad_objetos,inform.monto);
    dim = ceil(sqrt(inform.cantidad_objetos));
    montage(mostrar,'Size',[dim dim]);
    title (texto);
elseif FR == 4 %Mostrar los perimetros de segmentos
    fprintf("\n\n--->FORMATO DE RESPUESTA %i:  Mostrar los perimetros de segmentos\n\n",FR);
    mostrar = resultado.segmentos.proceso.perimetros;
    inform = resultado.global.informacion;
    texto   = sprintf("Cantidad de monedas: %d \n Monto total: $%d \n", inform.cantidad_objetos,inform.monto);
    dim = ceil(sqrt(inform.cantidad_objetos));
    montage(mostrar,'Size',[dim dim]);
    title (texto);
end
end