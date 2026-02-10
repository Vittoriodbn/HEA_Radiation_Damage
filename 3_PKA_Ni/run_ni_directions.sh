#!/bin/bash

# =================================================================
# SCRIPT SOLO PER NICHEL
# Direzioni: [100], [110], [135]
# =================================================================

# File di partenza (deve essere nella stessa cartella)
DATAFILE="ni_equilibrated.data"

# Definizione delle direzioni da calcolare
declare -a DIRECTIONS=("100" "110" "135")

# Loop sulle direzioni
for DIR in "${DIRECTIONS[@]}"; do
    
    echo "----------------------------------------------------------"
    echo "AVVIO SIMULAZIONE: Nichel - Direzione [$DIR]"
    echo "----------------------------------------------------------"

    # Calcolo componenti velocità per mantenere E = 3.3 keV (|v| ~1039.2)
    if [ "$DIR" == "100" ]; then
        # Lungo asse X
        VX="1039.2"
        VY="0.0"
        VZ="0.0"
    elif [ "$DIR" == "110" ]; then
        # Diagonale faccia: 1039.2 / sqrt(2) = 734.8
        VX="734.8"
        VY="734.8"
        VZ="0.0"
    elif [ "$DIR" == "135" ]; then
        # Direzione random: Vettore (1,3,5) -> Modulo sqrt(35) = 5.916
        # Fattore: 1039.2 / 5.916 = 175.66
        VX="175.7"
        VY="527.0"
        VZ="878.3"
    fi

    # Creazione del file di input temporanei per LAMMPS
    cat << EOF > in.temp_ni
# --- SETUP ---
units           metal
dimension       3
boundary        p p p
atom_style      atomic

# --- CARICAMENTO ---
read_data       $DATAFILE

# --- POTENZIALE ---
# Uso della definizione completa per evitare errori MEAM
pair_style      meam
pair_coeff      * * library.meam Co Ni Cr Fe Mn CoNiCrFeMn.meam Co Ni Cr Fe Mn

# --- REGIONI ---
region          core_box block 8.0 132.8 8.0 132.8 8.0 132.8 units box
group           core_atoms region core_box
group           boundary_atoms subtract all core_atoms

# --- PKA ---
reset_timestep  0
region          r_center sphere 70.4 70.4 70.4 1.0
group           PKA_candidates region r_center
variable        pka_id equal "count(PKA_candidates)" 
group           PKA region r_center

# --- FISICA ---
fix             1 all nve
fix             2 boundary_atoms langevin 300.0 300.0 1.0 98237
fix             3 all dt/reset 1 1.0e-5 1.0e-3 0.2

# --- OUTPUT ---
dump            1 all custom 100 dump.cascade_Ni_${DIR}.atom id type x y z
dump_modify     1 sort id

compute         T_core core_atoms temp
compute         T_bound boundary_atoms temp

# Log
log             log.Ni_${DIR}

thermo          100
thermo_style    custom step c_T_core c_T_bound pe press fmax dt

# --- RUN ---
velocity        PKA set $VX $VY $VZ
run             10000

# Salvataggio
write_data      ni_after_cascade_${DIR}.data
EOF

    echo ">>> Esecuzione LAMMPS per Ni [$DIR]..."
    
    # ESECUZIONE
    mpirun -np 4 lmp_mpi -in in.temp_ni

    echo ">>> Finito Ni [$DIR]."
    echo ">>> Pausa (10s)..."
    sleep 10
    
    # Pulizia
    rm in.temp_ni

done

echo "=========================================================="
echo "SIMULAZIONI NICHEL COMPLETATE (100, 110, 135)."
echo "=========================================================="
