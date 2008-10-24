/* Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

/* Implements area_roots.h */

#include <stdlib.h>

#include "scheme48.h"

#include "area_roots.h"
#include "areas.h"
#include "memory.h"
#include "memory_map.h"
#include "utils.h"
#include "data.h"
#include "measure.h"
#include "generation_gc.h"
#include "gc_config.h"

#if (S48_USE_REMEMBERED_SETS)
#include "remset.h"
#endif

/* initializes the dirty vector of AREA */
void s48_init_dirty_vector(Area* area) {

#if S48_DIRTY_VECTOR_METHOD==S48_ADDRESS_DIRTY_VECTORS
  Dirty_vector* dv = &area->dirty_vector;
  unsigned long area_size = area->end - area->start;
  unsigned long number_of_cards = area_size >> S48_LOG_CARD_SIZE ;
  dv->length = number_of_cards;
  /* A vector of pointers */
  dv->items = (s48_address*)calloc(sizeof(s48_address), number_of_cards);
#endif

#if S48_DIRTY_VECTOR_METHOD==S48_CROSSINGMAP_DIRTY_VECTORS
  Dirty_vector* dv = &area->dirty_vector;
  unsigned long area_size = area->end - area->start;
  unsigned long number_of_cards = area_size >> S48_LOG_CARD_SIZE ;
  dv->length = number_of_cards;
  /* This method uses two bits per card. One bit marks a card as
     beeing dirty, the second marks a card as beeing tracable, which
     means that the card does not begin within a B-vector (A string
     for example). We use a full char to store the bit. */
  dv->dirty_bits = (char*)calloc(sizeof(char), number_of_cards);
  dv->traceable_bits = (char*)calloc(sizeof(char), number_of_cards);
  dv->last_frontier = area->start;
#endif
}

/* deinitializes the dirty vector of AREA. (should free the memory
   allocated in init_dirty_vector */
void s48_deinit_dirty_vector(Area* area) {
#if S48_DIRTY_VECTOR_METHOD==S48_ADDRESS_DIRTY_VECTORS
  free(area->dirty_vector.items);
#endif

#if S48_DIRTY_VECTOR_METHOD==S48_CROSSINGMAP_DIRTY_VECTORS
  Dirty_vector* dv = &area->dirty_vector;
  free(dv->dirty_bits);
  free(dv->traceable_bits);
#endif
}

#if (MEASURE_GC)
static unsigned long areas_visited = 0;
static unsigned long areas_passed = 0;
#endif

inline static void call_trace_locationsB(Area* area,
					 s48_address start_address,
					 s48_address end_address) {
#if (MEASURE_GC)
  areas_passed += (end_address - start_address);
#endif
  
  s48_internal_trace_locationsB(area, TRUE, start_address, end_address,
				"s48_trace_areas_roots");
}

#if S48_DIRTY_VECTOR_METHOD==S48_CROSSINGMAP_DIRTY_VECTORS

inline static void update_new_traceable_bits(Area* area) {
  Dirty_vector* dirty_vector = &area->dirty_vector;
  char* traceable_bits = dirty_vector->traceable_bits;
    
  /* if new objects were allocated since the last trace, then scan
     the new part of the area to find out which of the new cards are
     traceable */
  s48_address start = area->start;
  s48_address addr = start; //dirty_vector->last_frontier;
  memset(dirty_vector->traceable_bits, 0, dirty_vector->length);
  
  while (addr < area->frontier) {
    /* TODO: optimization: we don't have to fetch all cells inside a d-vector */
    s48_value v = *((s48_value*)addr);
    unsigned long offset = addr - start;
    if ((offset % S48_CARD_SIZE) == 0) {
      traceable_bits[offset >> S48_LOG_CARD_SIZE] = 1;
    }
    
    if (S48_B_VECTOR_HEADER_P(v))
      addr = addr + S48_STOB_OVERHEAD_IN_A_UNITS +
	S48_HEADER_LENGTH_IN_A_UNITS(v);
    else
      addr = S48_ADDRESS_INC(addr);
  }
  /* remember that we have looked at this part of the area */
  dirty_vector->last_frontier = area->frontier;
}

#endif

/* trace (all possible) pointers to collected generations, in the
   old/uncollected area AREA */
void trace_area_roots(Area* area)
{
  /* the tracing can always be stopped at the trace pointer, because
     the part behind that (objects added the the area during the
     collection) will be traced later anyway. And the cards behind
     that will not be marked either. */

#if (MEASURE_GC)
  areas_visited += areas->frontier - areas->start;
#endif

#if S48_DIRTY_VECTOR_METHOD==S48_NO_DIRTY_VECTORS
  /* Without a dirty vector, we trace everything to be sure to catch
     all intergenerational pointers. */
  call_trace_locationsB(area, area->start, area->trace);
#endif

#if S48_DIRTY_VECTOR_METHOD==S48_ADDRESS_DIRTY_VECTORS
  /* This method stores the first location of an intergenerational
     pointer within a card (a fixed-sized part of the area). */
  Dirty_vector* dirty_vector = &area->dirty_vector;
  s48_address card_start_address = area->start;
  int i;

  for (i = 0;
       (i < dirty_vector->length) && (card_start_address < area->trace);
       i++, card_start_address += S48_CARD_SIZE) {
    s48_address start_address = dirty_vector->items[i];
    if (start_address != NULL) {
      s48_address end_address = card_start_address + S48_CARD_SIZE;

      /* no need to trace behind trace pointer */
      if (end_address > area->trace) end_address = area->trace;
      
      /* checks */
      if (start_address < card_start_address)
	s48_gc_error("s48_trace_areas_roots: dirty address too small.");
      if (start_address >= end_address)
	s48_gc_error("s48_trace_areas_roots: dirty address too big.");

      /* reset */
      dirty_vector->items[i] = NULL;

      /* trace */
      call_trace_locationsB(area, start_address, end_address);
    }
  } // for loop over dirty vector
#endif

#if S48_DIRTY_VECTOR_METHOD==S48_CROSSINGMAP_DIRTY_VECTORS
  /* This method uses two bits per card. One bit marks a card as
     beeing dirty, the second marks a card as beeing tracable, which
     means that the card does not begin within a B-vector (A string
     for example). The tracability is examined here "on demand" */
  Dirty_vector* dirty_vector = &area->dirty_vector;
  char* dirty_bits = dirty_vector->dirty_bits;
  char* traceable_bits = dirty_vector->traceable_bits;
  
  s48_address end_address;
  char searching; /* if searching for a traceable card in the loop */
  int i;

  int j; //for (j = 0; j < area->dirty_vector.length; ++j) assert((area->dirty_vector.traceable_bits[j] == 0) || (area->dirty_vector.traceable_bits[j] == 1));
  update_new_traceable_bits(area);
  for (j = 0; j < area->dirty_vector.length; ++j) assert((area->dirty_vector.traceable_bits[j] == 0) || (area->dirty_vector.traceable_bits[j] == 1));

  /* We start at the card containing the trace pointer, or the one
     before that, if the trace pointer is at the start of a card (or
     at the end of the area) */
  i = (area->trace - area->start) >> S48_LOG_CARD_SIZE;
  if (((area->trace - area->start) % S48_CARD_SIZE) == 0)
    i -= 1; /* can become -1 */
  end_address = area->trace;
  searching = 0;

  /* And go backwards through the vector, possibly continuing if a
     card is not traceable */
  for (; i >= 0; i--) {
    assert(i < dirty_vector->length);
    if (dirty_bits[i]) {
      dirty_bits[i] = 0;

      searching = 1;
    }
    if (searching) {
      if (traceable_bits[i]) {
	s48_address card_start_address = area->start + (i * S48_CARD_SIZE);
	/* end_address might still be the end of a higher card! */
	call_trace_locationsB(area, card_start_address, end_address);
	/* for the next card... */
	end_address = card_start_address;
	searching = 0;
      }
      /* the first card must be traceable. */
      else if (i == 0)
	s48_gc_error("s48_trace_areas_roots: first card not traceable.");
    }
  } // for loop over dirty vector
  assert(!searching);
  for (j = 0; j < area->dirty_vector.length; ++j) assert((area->dirty_vector.traceable_bits[j] == 0) || (area->dirty_vector.traceable_bits[j] == 1));
#endif

}

/* FPage 9 */

/* passes all dirty regions in all areas in the linked list starting
   with AREAS, to trace_locationsB */
void s48_trace_areas_roots(Area* areas) {
  while(areas != NULL) {
    trace_area_roots(areas);
    areas = areas->next;
  }
      
#if (MEASURE_GC)
  measure_areas_roots(areas_visited, areas_passed);
  areas_visited = 0;
  areas_passed = 0;
#endif
  
}
    
void s48_set_dirty_vector(Area* area, s48_address addr, long stob,
			  Area* maybe_to_area) {
  s48_set_dirty_vector_inline(area, addr, stob, maybe_to_area);
}
 
void s48_write_barrier(long stob, s48_address address, long value) {
  s48_write_barrier_inline(stob, address, value);
}
