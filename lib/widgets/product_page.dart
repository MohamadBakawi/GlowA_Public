import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:rayanpharma/pages/first_page.dart';
import 'package:rayanpharma/widgets/map_screen.dart';

class CreatevacanciesScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const CreatevacanciesScreen({super.key, this.initialLocation});

  @override
  State<CreatevacanciesScreen> createState() => _CreatevacanciesScreenState();
}

class _CreatevacanciesScreenState extends State<CreatevacanciesScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Controllers for form fields
  final _jobTitleController = TextEditingController();
  final _jobDescriptionController = TextEditingController();
  final _applicationDeadlineController = TextEditingController();
  final _postImgController = TextEditingController();
  final _minSalaryController = TextEditingController();
  final _locationController = TextEditingController();
  final _teamSizeController = TextEditingController();

  // Add a variable to hold the selected location
  LatLng? _selectedLocation;
  // Lists for multi-input fields
  List<String> _benefits = [];
  List<String> _skills = [];
  List<String> _requirements = [];
  List<String> _responsibilities = [];

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
// final FirebaseAuth _auth = FirebaseAuth.instance;

  // Dropdown state
  String? _selectedEmploymentType;
  String? _selectedExperienceLevel;
  String? _selectedEducationalRequirement;

  // Dropdown options
  final List<String> _employmentTypes = [
    'One time',
    'Contract',
    'Part time',
    'Full time'
  ];

  final List<String> _experienceLevels = List.generate(
      11, (index) => '$index ${index == 1 ? "year" : "years"}');

  final List<String> _educationalRequirements = [
    'None',
    'Trades',
    "Bachelor's",
    'Masters',
    'Ph.d'
  ];

 @override
  void initState() {
    super.initState();
    // If an initial location is provided, store it in _selectedLocation and update the text field.
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _locationController.text =
          'Lat: ${widget.initialLocation!.latitude.toStringAsFixed(4)}, Lng: ${widget.initialLocation!.longitude.toStringAsFixed(4)}';
    }
  }


  @override
  void dispose() {
    _pageController.dispose();
    _jobTitleController.dispose();
    _jobDescriptionController.dispose();
    _applicationDeadlineController.dispose();
    _postImgController.dispose();
    _minSalaryController.dispose();
    _locationController.dispose();
    _teamSizeController.dispose();
    super.dispose();
  }

  void _loadInitialData(Map<String, dynamic> data) {
    _jobTitleController.text = data['title'] ?? '';
    _jobDescriptionController.text = data['description'] ?? '';
    _applicationDeadlineController.text = data['deadline'] ?? '';
    _postImgController.text = data['postImg'] ?? '';
    _minSalaryController.text = data['fromRate'] ?? '';
    _benefits = List<String>.from(data['benefits'] ?? []);
    _skills = List<String>.from(data['skills'] ?? []);
    _requirements = List<String>.from(data['requirements'] ?? []);
    _responsibilities = List<String>.from(data['responsibilities'] ?? []);
    _selectedEmploymentType = data['employmentType'];
    _selectedExperienceLevel = data['experience'];
    _selectedEducationalRequirement = data['eduReq'];
  }

  Map<String, dynamic> _saveFormData() {
    return {
      'title': _jobTitleController.text,
      'description': _jobDescriptionController.text,
      'employmentType': _selectedEmploymentType,
      'experience': _selectedExperienceLevel,
      'deadline': _applicationDeadlineController.text,
      'postImg': _postImgController.text,
      'eduReq': _selectedEducationalRequirement,
      'fromRate': _minSalaryController.text,
      'responsibilities': _responsibilities,
      'benefits': _benefits,
      'skills': _skills,
      'requirements': _requirements,
    };
  }

 Future<void> _pickLocation() async {
    // Save current form data
    final formData = _saveFormData();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainMenu(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        // Assume the picked location is returned in result['location'] as a LatLng.
        _selectedLocation = result['location'];
        _locationController.text =
            'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}';
        _loadInitialData(result);
      });
    }
  }

  Future<List<String>> getPosterName() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return ['Unknown', ''];
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        String posterName = userData['name'] ?? 'Unknown';
        String posterUID = currentUser.uid;
        return [posterName, posterUID];
      } else {
        return ['Unknown', ''];
      }
    } catch (e) {
      print("Error fetching poster name: $e");
      return ['Unknown', ''];
    }
  }

 Future<void> _postJob() async {
    if (_selectedLocation == null) {
      // Optionally, show an error if no location is selected.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a location for the job.')),
      );
      return;
    }

    final posterInfo = await getPosterName(); // returns [posterName, posterUID]


    int teamSize = int.tryParse(_teamSizeController.text) ?? 0;
    List<dynamic> applications = []; // Initialize as an empty list

    final jobData = {
      'title': _jobTitleController.text,
      'description': _jobDescriptionController.text,
      'employmentType': _selectedEmploymentType ?? '',
      'experience': _selectedExperienceLevel ?? '',
      'deadline': _applicationDeadlineController.text,
      'postImg': _postImgController.text,
      'imageUrl': _postImgController.text,
      'eduReq': _selectedEducationalRequirement ?? '',
      // Here we send the location as a GeoPoint instead of a text
      'location': GeoPoint(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      ),
      'fromRate': _minSalaryController.text,
      'responsibilities': _responsibilities,
      'benefits': _benefits,
      'skills': _skills,
      'requirements': _requirements,

      'poster': posterInfo,
      'applications': applications,
      'posterUID': posterInfo[1],
      'createdAt': FieldValue.serverTimestamp(),
      'teamsize': teamSize,
    };

    try {
      await _firestore.collection('Job Postings').add(jobData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job posted successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error posting job: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post job')),
      );
    }
  }


  Future<void> _selectDate() async {
    DateTime now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate != null) {
      setState(() {
        _applicationDeadlineController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  Widget _buildPageOne() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Job Title'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _jobTitleController,
              hint: 'e.g., Senior UX Designer',
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Job Description'),
                Text(
                  '${_jobDescriptionController.text.length}/200',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _jobDescriptionController,
              hint: 'Details about the company',
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Job Location'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _locationController,
              hint: 'Tap to pick location',
              readOnly: true,
              onTap: _pickLocation,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Employment Type'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedEmploymentType,
                  hint: const Text('Select Employment Type'),
                  items: _employmentTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedEmploymentType = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Experience Level'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedExperienceLevel,
                  hint: const Text('Select Experience Level'),
                  items: _experienceLevels.map((level) {
                    return DropdownMenuItem<String>(
                      value: level,
                      child: Text(level),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedExperienceLevel = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Application Deadline'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _applicationDeadlineController,
              hint: 'Select Deadline',
              icon: Icons.calendar_today_outlined,
              readOnly: true,
              onTap: _selectDate,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Post Image'),
            const SizedBox(height: 8),
            // Tapping this field opens the image search overlay.
            _buildTextField(
              controller: _postImgController,
              hint: 'Tap to search for image',
              icon: Icons.image_outlined,
              readOnly: true,
              onTap: () async {
                final imageUrl = await showSearch<String>(
                  context: context,
                  delegate: ImageSearchDelegate(),
                );
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  setState(() {
                    _postImgController.text = imageUrl;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageTwo() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Educational Requirements'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedEducationalRequirement,
                  hint: const Text('Select Educational Requirement'),
                  items: _educationalRequirements.map((req) {
                    return DropdownMenuItem<String>(
                      value: req,
                      child: Text(req),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedEducationalRequirement = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Salary Range'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _minSalaryController,
              hint: '\$ 0',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Team Size'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _teamSizeController,
              hint: 'Enter team size',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Responsibilities'),
            const SizedBox(height: 8),
            MultiInputField(
              hintText: 'Enter a responsibility',
              items: _responsibilities,
              onChanged: (items) {
                setState(() {
                  _responsibilities = items;
                });
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Benefits'),
            const SizedBox(height: 8),
            MultiInputField(
              hintText: 'Enter a benefit',
              items: _benefits,
              onChanged: (items) {
                setState(() {
                  _benefits = items;
                });
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Skills'),
            const SizedBox(height: 8),
            MultiInputField(
              hintText: 'Enter a skill',
              items: _skills,
              onChanged: (items) {
                setState(() {
                  _skills = items;
                });
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Job Requirements'),
            const SizedBox(height: 8),
            MultiInputField(
              hintText: 'Enter a requirement',
              items: _requirements,
              onChanged: (items) {
                setState(() {
                  _requirements = items;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          if (_currentPage == 0) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            setState(() => _currentPage = 1);
          } else {
            await _postJob();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E225A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          _currentPage == 0 ? 'Next ￫' : 'Submit',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 18,
          ),
          onPressed: () {
            if (_currentPage > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              setState(() => _currentPage = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Create Vacancies',
          style: TextStyle(
            color: Colors.black,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPageOne(),
                _buildPageTwo(),
              ],
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }
}

class MultiInputField extends StatefulWidget {
  final String hintText;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;

  const MultiInputField({
    super.key,
    required this.hintText,
    required this.items,
    required this.onChanged,
  });

  @override
  State<MultiInputField> createState() => _MultiInputFieldState();
}

class _MultiInputFieldState extends State<MultiInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _addItem();
    }
  }

  void _addItem() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !_items.contains(text)) {
      setState(() {
        _items.add(text);
        _controller.clear();
        widget.onChanged(_items);
      });
    }
  }

  void _removeItem(String item) {
    setState(() {
      _items.remove(item);
      widget.onChanged(_items);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._items.map((item) {
          return Chip(
            label: Text(item),
            onDeleted: () => _removeItem(item),
          );
        }),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onSubmitted: (value) => _addItem(),
          ),
        ),
      ],
    );
  }
}

Widget _buildTextField({
  required TextEditingController controller,
  required String hint,
  int maxLines = 1,
  IconData? icon,
  bool readOnly = false,
  VoidCallback? onTap,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    readOnly: readOnly,
    onTap: onTap,
    keyboardType: hint == 'Enter team size' ? TextInputType.number : null,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[500]),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black),
      ),
      suffixIcon: icon != null ? Icon(icon, color: Colors.grey[700]) : null,
    ),
  );
}

Widget _buildSectionTitle(String title) {
  return Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
  );
}

class ImageSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: fetchImageUrls(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No images found for "$query"'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final imageUrl = snapshot.data![index];
            return GestureDetector(
              onTap: () {
                close(context, imageUrl);
              },
              child: Card(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.broken_image));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = ['Nature', 'Cars', 'Technology', 'Space'];
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          title: Text(suggestion),
          onTap: () {
            query = suggestion;
            showResults(context);
          },
        );
      },
    );
  }

  Future<List<String>> fetchImageUrls(String query) async {
    // Replace with your Unsplash API key.
    const String apiKey = "IZNVy6_sC6EtRCSlhesUVitG1pdorfepsFIFQ0yP5f0";
    final Uri url = Uri.parse(
        'https://api.unsplash.com/search/photos?query=${Uri.encodeComponent(query)}&per_page=20&client_id=$apiKey');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonBody = json.decode(response.body);
      final List<dynamic> results = jsonBody['results'];
      // Extract the "small" image urls from the results.
      return results
          .map((item) => item['urls']['small'] as String)
          .toList();
    } else {
      // On error, return an empty list.
      return [];
    }
  }
}
