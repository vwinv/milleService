import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:milleservices/models/service_category.dart';
import 'package:milleservices/providers/home_content_provider.dart';
import 'package:milleservices/providers/prestatairesProvider.dart';
import 'package:milleservices/providers/userProvider.dart';
import 'package:milleservices/navigation/app_navigation.dart';
import 'package:milleservices/services/sizeConfig.dart';
import 'package:milleservices/services/utilities.dart';
import 'package:milleservices/widgets/address_autocomplete_field.dart';
import 'package:milleservices/widgets/customButton.dart';
import 'package:provider/provider.dart';

class DemanderServicePage extends StatefulWidget {
  const DemanderServicePage({super.key});

  @override
  State<DemanderServicePage> createState() => _DemanderServicePageState();
}

class _DemanderServicePageState extends State<DemanderServicePage> {
  final TextEditingController addressPrestationController =
      TextEditingController();

  int? _selectedCategorie;
  int? _selectedDisponibilite;
  int? _selectedAvis;

  bool _openCategories = false;
  bool _openDisponibilite = false;
  bool _openAvis = false;

  DateTime? _plannedDate;

  final List<String> _disponibilites = const [
    'Services simple',
    'Express',
    'Urgence',
    'Planifier',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>().user;
      if (user != null && user.adresse != null) {
        addressPrestationController.text = user.adresse.toString();
      }
      context.read<PrestatairesProvider>().loadServicesIfNeeded();
    });
  }

  @override
  void dispose() {
    addressPrestationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeContentProvider>(
      builder: (context, homeContent, _) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.blockSizeHorizontal * 5,
              vertical: SizeConfig.blockSizeVertical * 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: Utilities().colorBlueDark,
                      ),
                      onPressed: () => homeContent.previousDemanderStep(),
                    ),
                    Text(
                      "demande_title".tr(),
                      style: TextStyle(
                        color: Utilities().colorBlueDark,
                        fontSize: SizeConfig.fontSize(
                          SizeConfig.blockSizeHorizontal * 4,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: SizeConfig.blockSizeVertical * 2),
                Container(
                  decoration: BoxDecoration(
                    color: Utilities().colorGreyLight,
                    borderRadius: BorderRadius.circular(
                      SizeConfig.blockSizeHorizontal * 10,
                    ),
                    border: Border.all(
                      color: Utilities().colorGreyLightDark,
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.blockSizeHorizontal * 3,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: SizeConfig.blockSizeHorizontal * 8,
                        height: SizeConfig.blockSizeVertical * 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(color: Colors.red, width: 5.5),
                        ),
                      ),
                      SizedBox(width: SizeConfig.blockSizeHorizontal * 3),
                      Expanded(
                        child: AddressAutocompleteField(
                          controller: addressPrestationController,
                          borderColor: Colors.transparent,
                          fillColor: Colors.transparent,
                          label: "",
                          labelStyle: TextStyle(
                            color: Colors.black,
                            fontSize: SizeConfig.blockSizeHorizontal * 3.5,
                            fontWeight: FontWeight.bold,
                          ),
                          placeholder: "demande_address_placeholder".tr(),
                          textfieldStyle: TextStyle(
                            color: Utilities().colorGreyDark,
                          ),
                          placeholderStyle: TextStyle(
                            color: Utilities().colorGreyDark,
                            fontSize: SizeConfig.blockSizeHorizontal * 4,
                            fontWeight: FontWeight.normal,
                          ),
                          height: SizeConfig.blockSizeVertical * 4,
                          width: SizeConfig.blockSizeHorizontal * 68,
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return "demande_address_required".tr();
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: SizeConfig.blockSizeVertical * 3),
                _buildCategoriesSection(),
                SizedBox(height: SizeConfig.blockSizeVertical * 1),
                _buildDisponibiliteSection(),
                /*  SizedBox(height: SizeConfig.blockSizeVertical * 2),
                _buildAvisSection(), */
                SizedBox(height: SizeConfig.blockSizeVertical * 5),
                CustomButton(
                  onTap: () {
                    _onRechercher();
                    AppNavigation.pushParticulierSearch(context);
                  },
                  title: Center(
                    child: Text(
                      "demande_search_button".tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: SizeConfig.blockSizeHorizontal * 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  color: Utilities().colorYellow,
                  borderColor: Utilities().colorBlueDark,
                  width: SizeConfig.blockSizeHorizontal * 90,
                  height: SizeConfig.blockSizeVertical * 6,
                  borderRadius: SizeConfig.blockSizeHorizontal * 10,
                ),

              ],
            ),
          ),
        );
      },
    );
  }

  /// Action du bouton \"Rechercher\".
  Future<void> _onRechercher() async {
    print("onRechercher");
    final prestatairesProvider = context.read<PrestatairesProvider>();

    final services = prestatairesProvider.services;
    String serviceId = '';
    if (_selectedCategorie != null &&
        _selectedCategorie! >= 0 &&
        _selectedCategorie! < services.length) {
      final ServiceCategory selectedService = services[_selectedCategorie!];
      serviceId = selectedService.id;
    }
    String? dateParam;
    if (_selectedDisponibilite == 3 && _plannedDate != null) {
      // Planifier -> on envoie la date au format YYYY-MM-DD
      final d = _plannedDate!;
      dateParam =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    final userProvider = context.read<UserProvider>();
    await prestatairesProvider.loadSearch(
      serviceId: serviceId,
      tarifMin: null,
      tarifMax: null,
      date: dateParam,
      userProvider: userProvider,
    );
  }

  Widget _buildSectionHeader(
    String title, {
    required bool isOpen,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SizeConfig.blockSizeHorizontal * 10),
      child: Padding(
        padding: EdgeInsets.only(left: SizeConfig.blockSizeHorizontal * 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Utilities().colorBlueDark,
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.5,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Utilities().colorGreyDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillChip({
    required String label,
    required bool selected,
    IconData? icon,
  }) {
    final bg = selected ? Utilities().colorYellow : Utilities().colorBlueDark;
    final fg = selected ? Colors.black : Colors.white;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 5,
        vertical: SizeConfig.blockSizeVertical * 1.2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(
          SizeConfig.blockSizeHorizontal * 10,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 3),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (icon != null) ...[
            SizedBox(width: SizeConfig.blockSizeHorizontal * 1.5),
            Icon(icon, size: 16, color: fg),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final prestatairesProvider = context.watch<PrestatairesProvider>();
    final List<ServiceCategory> categories = prestatairesProvider.services;
    final bool loading = prestatairesProvider.servicesLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Utilities().colorGreyLight,
            borderRadius: BorderRadius.circular(
              SizeConfig.blockSizeHorizontal * 10,
            ),
            border: Border.all(color: Utilities().colorGreyLightDark, width: 1),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.blockSizeHorizontal * 5,
            vertical: SizeConfig.blockSizeVertical * 1.5,
          ),
          child: _buildSectionHeader(
            'Catégories de Services',
            isOpen: _openCategories,
            onTap: () => setState(() => _openCategories = !_openCategories),
          ),
        ),
        if (_openCategories)
          SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
        if (_openCategories)
          Padding(
            padding: EdgeInsets.only(left: SizeConfig.blockSizeHorizontal * 2),
            child: loading
                ? Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: SizeConfig.blockSizeVertical * 2,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : (categories.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: SizeConfig.blockSizeVertical * 1.5,
                          ),
                          child: Text(
                            'Aucun service',
                            style: TextStyle(
                              color: Utilities().colorGreyDark,
                              fontSize: SizeConfig.fontSize(
                                SizeConfig.blockSizeHorizontal * 3,
                              ),
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: SizeConfig.blockSizeHorizontal * 2.5,
                          runSpacing: SizeConfig.blockSizeVertical * 1.5,
                          children: List.generate(categories.length, (index) {
                            final selected = _selectedCategorie == index;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedCategorie = index);
                              },
                              child: _buildPillChip(
                                label: categories[index].libelle,
                                selected: selected,
                              ),
                            );
                          }),
                        )),
          ),
      ],
    );
  }

  Widget _buildDisponibiliteSection() {
    final now = DateTime.now();
    final minDate = DateTime(now.year, now.month, now.day);
    final initialDate = _plannedDate ?? minDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Utilities().colorGreyLight,
            borderRadius: BorderRadius.circular(
              SizeConfig.blockSizeHorizontal * 10,
            ),
            border: Border.all(color: Utilities().colorGreyLightDark, width: 1),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.blockSizeHorizontal * 5,
            vertical: SizeConfig.blockSizeVertical * 1.5,
          ),
          child: _buildSectionHeader(
            'Disponibilité',
            isOpen: _openDisponibilite,
            onTap: () =>
                setState(() => _openDisponibilite = !_openDisponibilite),
          ),
        ),
        if (_openDisponibilite)
          SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
        if (_openDisponibilite)
          Padding(
            padding: EdgeInsets.only(left: SizeConfig.blockSizeHorizontal * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: SizeConfig.blockSizeHorizontal * 2.5,
                  runSpacing: SizeConfig.blockSizeVertical * 1.5,
                  children: List.generate(_disponibilites.length, (index) {
                    final selected = _selectedDisponibilite == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDisponibilite = index);
                      },
                      child: _buildPillChip(
                        label: _disponibilites[index],
                        selected: selected,
                        icon: index == 3 ? Icons.calendar_today_outlined : null,
                      ),
                    );
                  }),
                ),
                if (_selectedDisponibilite == 3)
                  SizedBox(height: SizeConfig.blockSizeVertical * 2),
                if (_selectedDisponibilite == 3)
                  SizedBox(
                    height: SizeConfig.blockSizeVertical * 20,
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(
                        brightness: Brightness.light,
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: initialDate.isBefore(minDate)
                            ? minDate
                            : initialDate,
                        minimumDate: minDate,
                        maximumDate: minDate.add(const Duration(days: 365)),
                        onDateTimeChanged: (date) {
                          setState(() {
                            _plannedDate = date;
                          });
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAvisChip(String label, int stars, bool selected) {
    final bg = selected ? Utilities().colorBlueDark : Colors.white;
    final fg = selected ? Colors.white : Colors.black;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 4,
        vertical: SizeConfig.blockSizeVertical * 1.2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(
          SizeConfig.blockSizeHorizontal * 10,
        ),
        border: Border.all(color: Utilities().colorBlueDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: SizeConfig.fontSize(SizeConfig.blockSizeHorizontal * 3),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: SizeConfig.blockSizeHorizontal * 2),
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < stars ? Icons.star : Icons.star_border,
                size: 16,
                color: Utilities().colorYellow,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAvisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Utilities().colorGreyLight,
            borderRadius: BorderRadius.circular(
              SizeConfig.blockSizeHorizontal * 10,
            ),
            border: Border.all(color: Utilities().colorGreyLightDark, width: 1),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.blockSizeHorizontal * 5,
            vertical: SizeConfig.blockSizeVertical * 1.5,
          ),
          child: _buildSectionHeader(
            'Avis clients',
            isOpen: _openAvis,
            onTap: () => setState(() => _openAvis = !_openAvis),
          ),
        ),
        if (_openAvis) SizedBox(height: SizeConfig.blockSizeVertical * 1.5),
        if (_openAvis)
          Wrap(
            spacing: SizeConfig.blockSizeHorizontal * 2.5,
            runSpacing: SizeConfig.blockSizeVertical * 1.5,
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedAvis = 0),
                child: _buildAvisChip('Meilleur', 5, _selectedAvis == 0),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedAvis = 1),
                child: _buildAvisChip('Moyen', 3, _selectedAvis == 1),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedAvis = 2),
                child: _buildAvisChip('Faible', 2, _selectedAvis == 2),
              ),
            ],
          ),
      ],
    );
  }

}
