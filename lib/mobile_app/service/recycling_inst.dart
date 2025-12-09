class RecyclingInstructions {
  static const Map<String, String> instructions = {
    'plastic':
        '''1. Clean the plastic item thoroughly to remove any food residue or labels.
2. Check the recycling number on the bottom (1-7) to determine recyclability.
3. Remove caps and lids if they're made of different plastic types.
4. Place in your recycling bin or take to a plastic recycling center.
5. Avoid putting plastic bags in curbside recycling - take them to grocery store collection points.''',

    'paper': '''1. Remove any plastic wrapping, tape, or staples from the paper.
2. Ensure the paper is clean and dry - no food stains or grease.
3. Flatten cardboard boxes and paper items to save space.
4. Place in your paper recycling bin or bundle together.
5. Avoid recycling wax-coated paper, tissues, or paper towels.''',

    'glass':
        '''1. Rinse the glass container to remove any food or liquid residue.
2. Remove metal lids and caps (recycle these separately).
3. Leave labels on - they'll be removed during the recycling process.
4. Place in your glass recycling bin or take to a glass recycling center.
5. Separate by color if your local facility requires it (clear, brown, green).''',

    'metal': '''1. Clean the metal item to remove any food residue or labels.
2. Remove any non-metal components like plastic handles or rubber seals.
3. Crush aluminum cans to save space, but don't crush steel cans.
4. Place in your metal recycling bin or take to a scrap metal dealer.
5. Separate ferrous (magnetic) and non-ferrous metals if required.''',

    'cardboard': '''1. Break down boxes and flatten them to save space.
2. Remove any plastic tape, labels, or packing materials.
3. Ensure cardboard is clean and dry - no grease or food stains.
4. Place in your cardboard recycling bin or bundle together.
5. Avoid recycling wax-coated or laminated cardboard.''',

    'organic': '''1. Separate organic waste from other materials immediately.
2. Place in a compost bin or organic waste collection container.
3. Keep away from meat, dairy, and oily foods unless your facility accepts them.
4. Turn compost regularly if composting at home.
5. Consider starting a home compost system for garden benefits.''',

    'trash':
        '''This item cannot be recycled through standard programs. Consider these options:
1. Check if it can be repaired or repurposed instead of discarding.
2. Look for specialized recycling programs for this type of material.
3. Dispose of it properly in your regular trash bin.
4. Consider donating if the item is still usable.
5. Research local hazardous waste disposal if it contains harmful materials.''',
  };

  static String getInstructions(String category) {
    // Try to match the category with our instructions
    final lowerCategory = category.toLowerCase();

    // Direct matches
    if (instructions.containsKey(lowerCategory)) {
      return instructions[lowerCategory]!;
    }

    // Partial matches for common variations
    if (lowerCategory.contains('plastic') || lowerCategory.contains('bottle')) {
      return instructions['plastic']!;
    } else if (lowerCategory.contains('paper') ||
        lowerCategory.contains('newspaper') ||
        lowerCategory.contains('magazine')) {
      return instructions['paper']!;
    } else if (lowerCategory.contains('glass') ||
        lowerCategory.contains('jar') ||
        lowerCategory.contains('bottle glass')) {
      return instructions['glass']!;
    } else if (lowerCategory.contains('metal') ||
        lowerCategory.contains('can') ||
        lowerCategory.contains('aluminum') ||
        lowerCategory.contains('steel')) {
      return instructions['metal']!;
    } else if (lowerCategory.contains('cardboard') ||
        lowerCategory.contains('box')) {
      return instructions['cardboard']!;
    } else if (lowerCategory.contains('organic') ||
        lowerCategory.contains('food') ||
        lowerCategory.contains('compost')) {
      return instructions['organic']!;
    }

    // Default to trash instructions for unknown categories
    return instructions['trash']!;
  }
}
