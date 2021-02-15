data "azurerm_image" "presto" {
  resource_group_name = "packer-presto-images"
  name_regex          = "^presto-\\d{4,4}-\\d{2,2}-\\d{2,2}T\\d{6,6}"
  sort_descending     = true
}

data "azurerm_image" "presto-client" {
  resource_group_name = "packer-presto-images"
  name_regex          = "^prestoclients-\\d{4,4}-\\d{2,2}-\\d{2,2}T\\d{6,6}"
  sort_descending     = true
}
