import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex; // Active page index

  const BottomNavBar({
    required this.currentIndex,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex, // Current selected index
      onTap: (index) {
        // Handle navigation based on the index
        switch (index) {
          case 0: // Home
            Navigator.pushReplacementNamed(
                context, '/home'); // Replace current page with home
            break;
          case 1: // Reports
            Navigator.pushReplacementNamed(
                context, '/reports'); // Replace current page with reports
            break;
          case 2: // Profile
            Navigator.pushReplacementNamed(
                context, '/profile'); // Replace current page with profile
            break;
          default:
            break;
        }
      },
/////////////////////////////////////////////////////////////////////////////////////
      // onTap: (index) {
      //   // Handle navigation based on the index
      //   switch (index) {
      //     case 0: // Home
      //       // Navigator.of(context)
      //       //     .popUntil((route) => '/home' == route.settings.name);
      //       Navigator.pushNamed(context, '/home'); // Navigate to home
      //       break;
      //     case 1: // Reports
      //       Navigator.pushNamed(context, '/reports'); // Navigate to settings
      //       break;
      //     case 2: // Profile
      //       Navigator.pushNamed(context, '/profile'); // Navigate to profile
      //       break;
      //     default:
      //       break;
      //   }
      // },
////////////////////////////////////////////////////////////////////////////////////
      // onTap: (index) {
      //   // Handle navigation based on the index
      //   switch (index) {
      //     case 0: // Home
      //       if (ModalRoute.of(context)?.settings.name != '/home') {
      //         Navigator.pushNamedAndRemoveUntil(
      //           context,
      //           '/home',
      //           (route) => false, // Remove all routes
      //         );
      //       }
      //       break;
      //     case 1: // Reports
      //       if (ModalRoute.of(context)?.settings.name != '/reports') {
      //         Navigator.pushReplacementNamed(context, '/reports');
      //       }
      //       break;
      //     case 2: // Profile
      //       if (ModalRoute.of(context)?.settings.name != '/profile') {
      //         Navigator.pushReplacementNamed(context, '/profile');
      //       }
      //       break;
      //     default:
      //       break;
      //   }
      // },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined),
          label: 'Reports',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
      selectedItemColor: Colors.blue, // Color of the selected item
      unselectedItemColor: Colors.grey, // Color of the unselected items
      showUnselectedLabels: true, // Show labels for unselected items
    );
  }
}
