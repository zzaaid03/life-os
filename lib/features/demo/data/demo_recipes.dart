/// Canned recipes for the sandbox demo mode.
///
/// Used by both the demo chef (as generated answers) and the demo recipe
/// repository (as saved rows). Written as wire-shape maps and parsed through
/// [Recipe.fromJson], so they go through exactly the same parsing a real
/// `recipe-chef` answer does.
///
/// Between them they cover everything the recipe screens render: prep notes,
/// staples, "to taste" amounts, per-step ingredients, tips, and at least two
/// timers each. The pasta has a 30 second timer so a visitor can watch one
/// ring without waiting.
library;

import 'package:life_os/features/recipes/data/models/recipe.dart';

/// The three canned recipes, in the order the demo chef hands them out.
const List<Map<String, dynamic>> demoRecipeMaps = [
  {
    'title': 'Lemon Garlic Chicken Traybake',
    'emoji': '🍋',
    'description':
        'Crispy chicken thighs and golden potatoes roasted in one tray with '
        'lemon, garlic and oregano.',
    'gradient': ['#F7D154', '#E8873A'],
    'servings': 4,
    'prepMinutes': 15,
    'cookMinutes': 50,
    'difficulty': 'easy',
    'ingredients': [
      {'name': 'chicken thighs', 'amount': 800, 'unit': 'g', 'prep': 'bone in, skin on'},
      {'name': 'baby potatoes', 'amount': 600, 'unit': 'g', 'prep': 'halved'},
      {'name': 'lemon', 'amount': 1, 'prep': 'cut into wedges'},
      {'name': 'garlic cloves', 'amount': 6, 'prep': 'lightly crushed'},
      {'name': 'red onion', 'amount': 1, 'prep': 'cut into wedges'},
      {'name': 'olive oil', 'amount': 3, 'unit': 'tbsp', 'staple': true},
      {'name': 'dried oregano', 'amount': 2, 'unit': 'tsp'},
      {'name': 'salt', 'amount': null, 'staple': true},
      {'name': 'black pepper', 'amount': null, 'staple': true},
      {'name': 'fresh parsley', 'amount': 10, 'unit': 'g', 'prep': 'chopped'},
    ],
    'steps': [
      {'text': 'Heat the oven to 200C (180C fan).', 'ingredients': <int>[]},
      {
        'text':
            'Toss the potatoes and onion in a large roasting tray with the '
            'olive oil, oregano, salt and pepper.',
        'ingredients': [1, 4, 5, 6, 7, 8],
      },
      {
        'text':
            'Nestle the chicken in skin side up, tuck in the garlic and lemon '
            'wedges, and squeeze a little lemon over the top.',
        'ingredients': [0, 2, 3],
      },
      {
        'text':
            'Roast until the chicken skin is crisp and the potatoes are '
            'golden.',
        'timerSeconds': 2700,
        'timerLabel': 'Roast traybake',
        'ingredients': <int>[],
      },
      {
        'text':
            'Let it rest out of the oven, then scatter over the parsley and '
            'serve straight from the tray.',
        'timerSeconds': 300,
        'timerLabel': 'Rest chicken',
        'ingredients': [9],
      },
    ],
    'tips': [
      'Pat the chicken dry before roasting for the crispiest skin.',
      'Squeeze the roasted garlic out of its skin and mash it into the juices.',
    ],
  },
  {
    'title': 'Creamy Tomato Pasta',
    'emoji': '🍝',
    'description':
        'A quick weeknight pasta in a silky tomato and parmesan sauce, '
        'ready in about 20 minutes.',
    'gradient': ['#F28B66', '#C8423B'],
    'servings': 2,
    'prepMinutes': 5,
    'cookMinutes': 15,
    'difficulty': 'easy',
    'ingredients': [
      {'name': 'penne', 'amount': 200, 'unit': 'g'},
      {'name': 'olive oil', 'amount': 1, 'unit': 'tbsp', 'staple': true},
      {'name': 'garlic cloves', 'amount': 2, 'prep': 'finely chopped'},
      {'name': 'tomato passata', 'amount': 400, 'unit': 'g'},
      {'name': 'double cream', 'amount': 100, 'unit': 'ml'},
      {'name': 'parmesan', 'amount': 30, 'unit': 'g', 'prep': 'finely grated'},
      {'name': 'fresh basil', 'amount': 10, 'unit': 'g', 'prep': 'torn'},
      {'name': 'salt', 'amount': null, 'staple': true},
      {'name': 'black pepper', 'amount': null, 'staple': true},
    ],
    'steps': [
      {
        'text':
            'Bring a large pan of well salted water to the boil and cook the '
            'penne until just tender.',
        'timerSeconds': 600,
        'timerLabel': 'Cook pasta',
        'ingredients': [0, 7],
      },
      {
        'text':
            'Meanwhile, warm the olive oil in a frying pan and fry the garlic '
            'until fragrant but not brown.',
        'timerSeconds': 30,
        'timerLabel': 'Fry garlic',
        'ingredients': [1, 2],
      },
      {
        'text': 'Pour in the passata and let it bubble gently to thicken.',
        'timerSeconds': 480,
        'timerLabel': 'Simmer sauce',
        'ingredients': [3],
      },
      {
        'text':
            'Stir in the cream and parmesan, then season with salt and '
            'pepper.',
        'ingredients': [4, 5, 8],
      },
      {
        'text':
            'Drain the pasta, toss it through the sauce with a splash of the '
            'cooking water, and finish with the basil.',
        'ingredients': [6],
      },
    ],
    'tips': [
      'Save a mug of pasta water before draining. It makes the sauce glossy.',
    ],
  },
  {
    'title': 'Thai Green Curry',
    'emoji': '🍛',
    'description':
        'A fragrant coconut curry with chicken, green beans and peppers, '
        'served over jasmine rice.',
    'gradient': ['#9BD770', '#3E8E5A'],
    'servings': 4,
    'prepMinutes': 15,
    'cookMinutes': 25,
    'difficulty': 'medium',
    'ingredients': [
      {'name': 'chicken breast', 'amount': 500, 'unit': 'g', 'prep': 'sliced into strips'},
      {'name': 'coconut milk', 'amount': 400, 'unit': 'ml'},
      {'name': 'green curry paste', 'amount': 3, 'unit': 'tbsp'},
      {'name': 'vegetable oil', 'amount': 1, 'unit': 'tbsp', 'staple': true},
      {'name': 'green beans', 'amount': 150, 'unit': 'g', 'prep': 'trimmed and halved'},
      {'name': 'red pepper', 'amount': 1, 'prep': 'sliced'},
      {'name': 'fish sauce', 'amount': 1, 'unit': 'tbsp'},
      {'name': 'brown sugar', 'amount': 1, 'unit': 'tsp'},
      {'name': 'lime', 'amount': 1, 'prep': 'juiced'},
      {'name': 'jasmine rice', 'amount': 300, 'unit': 'g', 'prep': 'rinsed'},
      {'name': 'fresh coriander', 'amount': null, 'prep': 'chopped'},
      {'name': 'water', 'amount': 450, 'unit': 'ml', 'staple': true},
    ],
    'steps': [
      {
        'text':
            'Put the rice and water in a pan, bring to the boil, then cover '
            'and cook on the lowest heat.',
        'timerSeconds': 720,
        'timerLabel': 'Cook rice',
        'ingredients': [9, 11],
      },
      {
        'text':
            'Heat the oil in a wok or deep pan and fry the curry paste, '
            'stirring, until it smells fragrant.',
        'timerSeconds': 60,
        'timerLabel': 'Fry paste',
        'ingredients': [2, 3],
      },
      {
        'text': 'Add the chicken and stir until it is sealed all over.',
        'ingredients': [0],
      },
      {
        'text':
            'Pour in the coconut milk, add the green beans and pepper, and '
            'simmer until the chicken is cooked through.',
        'timerSeconds': 600,
        'timerLabel': 'Simmer curry',
        'ingredients': [1, 4, 5],
      },
      {
        'text':
            'Season with the fish sauce, sugar and lime juice, scatter over '
            'the coriander and serve with the rice.',
        'ingredients': [6, 7, 8, 10],
      },
    ],
    'tips': [
      'Taste before serving: add more lime for sharpness or sugar to soften it.',
      'Swap the chicken for tofu and the fish sauce for soy to make it vegetarian.',
    ],
  },
];

/// Parses canned recipe [index] (wrapped into range).
Recipe demoRecipe(int index) =>
    Recipe.fromJson(demoRecipeMaps[index % demoRecipeMaps.length]);
