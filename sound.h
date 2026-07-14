/* gameplaySP
 *
 * Copyright (C) 2006 Exophase <exophase@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#ifndef SOUND_H
#define SOUND_H

#ifndef BUFFER_SIZE
#define BUFFER_SIZE        (1 << 16)
#endif
#define BUFFER_SIZE_MASK   (BUFFER_SIZE - 1)

/* The rate the mixer runs at. Nothing here assumes a power of two, so a target
 * whose audio hardware wants a particular rate can just say so and skip a
 * resampling pass it has no cycles for. */
#ifndef GBA_SOUND_FREQUENCY
#define GBA_SOUND_FREQUENCY   (64 * 1024)
#endif

#ifdef OVERCLOCK_60FPS
  #define GBC_BASE_RATE ((float)(60 * 228 * (272+960)))
  /* Integer companion used by the deterministic audio path. Keeping the
   * float form above for the frontend timing field / RTC / rumble, which
   * legitimately want float results. */
  #define GBC_BASE_RATE_INT ((u32)(60 * 228 * (272+960)))
#else
  #define GBC_BASE_RATE ((float)(16 * 1024 * 1024))
  #define GBC_BASE_RATE_INT ((u32)(16 * 1024 * 1024))
#endif

#define DIRECT_SOUND_INACTIVE         0
#define DIRECT_SOUND_RIGHT            1
#define DIRECT_SOUND_LEFT             2
#define DIRECT_SOUND_LEFTRIGHT        3

typedef struct
{
   s8 fifo[32];
   u32 fifo_base;
   u32 fifo_top;
   fixed8_24 fifo_fractional;
   // The + 1 is to give some extra room for linear interpolation
   // when wrapping around.
   u32 buffer_index;
   u32 status;
   u32 volume_halve;
} direct_sound_struct;

#define GBC_SOUND_INACTIVE            0
#define GBC_SOUND_RIGHT               1
#define GBC_SOUND_LEFT                2
#define GBC_SOUND_LEFTRIGHT           3


typedef struct
{
   u32 rate;
   fixed16_16 frequency_step;
   fixed16_16 sample_index;
   fixed16_16 tick_counter;
   u32 total_volume;
   u32 envelope_initial_volume;
   u32 envelope_volume;
   u32 envelope_direction;
   u32 envelope_status;
   u32 envelope_ticks;
   u32 envelope_initial_ticks;
   u32 sweep_status;
   u32 sweep_direction;
   u32 sweep_ticks;
   u32 sweep_initial_ticks;
   u32 sweep_shift;
   u32 length_status;
   u32 length_ticks;
   u32 noise_type;
   u32 wave_type;
   u32 wave_bank;
   u32 wave_volume;
   u32 status;
   u32 active_flag;
   u32 master_enable;
   u32 sample_table_idx;
} gbc_sound_struct;

const extern s8 square_pattern_duty[4][8];
extern direct_sound_struct direct_sound_channel[2];
extern gbc_sound_struct gbc_sound_channel[4];
extern u32 gbc_sound_master_volume_left;
extern u32 gbc_sound_master_volume_right;
extern u32 gbc_sound_master_volume;
extern u32 gbc_sound_buffer_index;
extern u32 gbc_sound_last_cpu_ticks;

extern const u32 sound_frequency;
extern u32 sound_on;

/* The PSG frequency-step numerators, as a function of the output rate.
 *
 * These used to exist twice: once here (well, in sound.c) for the sweep path,
 * and once over in gba_memory.c's I/O-write macros for note-on — as the
 * constants they reduce to at gpSP's stock 65536 Hz (2^20 for tone, 2^21 for
 * wave, 2^20/2^19 for noise). The sound.c copy was made rate-aware when the
 * PSG played five semitones flat; the gba_memory.c copies were missed, so at
 * 48 kHz every PSG NOTE-ON was 65536/48000 = 5.39 semitones SHARP, while a
 * mid-note sweep snapped it back to true. PCM instruments were fine, which is
 * why it presented as "only some instruments sound wrong". One definition,
 * used by both files, so the two paths cannot disagree again.
 *
 * GBC_FREQ_STEP_NUM        131072*8*65536 / out_rate  (tone: /(2048-rate))
 * GBC_WAVE_FREQ_STEP_NUM   2 x the above              (wave: /(2048-rate))
 * GBC_NOISE_FREQ_STEP(...) the noise divider tree, 16.16
 */
#define GBC_FREQ_STEP_NUM \
  ((u32)(68719476736ULL / (u64)GBA_SOUND_FREQUENCY))
#define GBC_WAVE_FREQ_STEP_NUM \
  ((u32)(137438953472ULL / (u64)GBA_SOUND_FREQUENCY))
#define GBC_NOISE_FREQ_STEP_R0(shift) \
  ((u32)((((u64)1048576u << 16) / GBA_SOUND_FREQUENCY) >> ((shift) + 1)))
#define GBC_NOISE_FREQ_STEP(ratio, shift) \
  ((u32)((((u64)524288u << 16) / ((u64)(ratio) * GBA_SOUND_FREQUENCY)) >> ((shift) + 1)))

void sound_timer_queue32(u32 channel, u32 value);
u32 sound_fifo_rate_hz(void);
unsigned sound_timer(fixed8_24 frequency_step, u32 channel);
void sound_reset_fifo(u32 channel);
void render_gbc_sound();
void init_sound();

bool sound_check_savestate(const u8 *src);
unsigned sound_write_savestate(u8 *dst);
bool sound_read_savestate(const u8 *src);

u32 sound_read_samples(s16 *out, u32 frames);

void reset_sound(void);

#endif
