/*
 Copyright (c) 2010 The WebM project authors. All Rights Reserved.
 
 Use of this source code is governed by a BSD-style license
 that can be found in the LICENSE file in the root of the source
 tree. An additional intellectual property rights grant can be found
 in the file PATENTS.  All contributing project authors may
 be found in the AUTHORS file in the root of the source tree.
 */


/*
 This is an example of a simple decoder loop. It takes an input file
 containing the compressed data (in IVF format), passes it through the
 decoder, and writes the decompressed frames to disk. Other decoder
 examples build upon this one.
 
 The details of the IVF format have been elided from this example for
 simplicity of presentation, as IVF files will not generally be used by
 your application. In general, an IVF file consists of a file header,
 followed by a variable number of frames. Each frame consists of a frame
 header followed by a variable length payload. The length of the payload
 is specified in the first four bytes of the frame header. The payload is
 the raw compressed data.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#define VPX_CODEC_DISABLE_COMPAT 1
#include "vpx_decoder.h"
#include "vp8dx.h"
#define interface (vpx_codec_vp8_dx())


#define IVF_FILE_HDR_SZ  (32)
#define IVF_FRAME_HDR_SZ (12)

static unsigned int mem_get_le32(const unsigned char *mem) {
    return (mem[3] << 24)|(mem[2] << 16)|(mem[1] << 8)|(mem[0]);
}

static void decoder_die(const char *fmt, ...) {
    va_list ap;
    
    va_start(ap, fmt);
    vprintf(fmt, ap);
    if(fmt[strlen(fmt)-1] != '\n')
        printf("\n");
    exit(EXIT_FAILURE);
}

static void decoder_die_codec(vpx_codec_ctx_t *ctx, const char *s) {
    const char *detail = vpx_codec_error_detail(ctx);               
    //
    printf("%s: %s\n", s, vpx_codec_error(ctx));                    
    if(detail)                                                      
        printf("    %s\n",detail);                                  
    exit(EXIT_FAILURE);                                             
}

static vpx_codec_ctx_t  decoder_codec;
static int              decoder_flags = 0, decoder_frame_cnt = 0;

//unsigned char    frame_hdr[IVF_FRAME_HDR_SZ];
//unsigned char    frame[256*1024];

unsigned char * output[1024*1024];

static vpx_codec_err_t  decoder_res;

void setup_decoder( char* infile_path )
{
        
        (void)decoder_res;
        
        printf("Using %s\n",vpx_codec_iface_name(interface));
        /* Initialize codec */
        if(vpx_codec_dec_init(&decoder_codec, interface, NULL, decoder_flags))
            decoder_die_codec(&decoder_codec, "Failed to initialize decoder");
        
}

void decode_frame(vpx_image_t *img, unsigned char * frame_hdr, unsigned char* frame, char* ret) {
    
    // Read frame header
    //fread(frame_hdr, 1, IVF_FRAME_HDR_SZ, decoder_infile);
            
    int               frame_sz = mem_get_le32(frame_hdr);
    vpx_codec_iter_t  iter = NULL;
    decoder_frame_cnt++;
    
    //if(frame_sz > sizeof(frame))
    //    decoder_die("Frame %d data too big for example code buffer %d", frame_sz, sizeof(frame));
    
    // Read frame
    //if(fread(frame, 1, frame_sz, decoder_infile) != frame_sz)
    //    decoder_die("Frame %d failed to read complete frame", decoder_frame_cnt);
    
    /* Decode the frame */
    if(vpx_codec_decode(&decoder_codec, frame, frame_sz, NULL, 0))
        decoder_die_codec(&decoder_codec, "Failed to decode frame");
    
    /* Write decoded data to buffer */

    img = vpx_codec_get_frame(&decoder_codec, &iter);
        
    unsigned int plane, y;

    for(plane=0; plane < 3; plane++) {
        
        unsigned char *buf =img->planes[plane];
        //
        for(y=0; y < (plane ? (img->d_h + 1) >> 1 : img->d_h); y++) {

            
            // Write output to file
            //fwrite(buf, 1, (plane ? (img->d_w + 1) >> 1 : img->d_w), outfile);                                            
            //buf += img->stride[plane];
            
            memcpy(ret, buf, (plane ? (img->d_w + 1) >> 1 : img->d_w));
            ret += (plane ? (img->d_w + 1) >> 1 : img->d_w);
            buf += img->stride[plane];

        }
        
        
    }
    
}

void finalise_decoder() {
    
    printf("Processed %d frames.\n",decoder_frame_cnt);
    if(vpx_codec_destroy(&decoder_codec))
        decoder_die_codec(&decoder_codec, "Failed to destroy codec");
        
}
