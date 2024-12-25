#include <linux/module.h>
#include <linux/init.h>
#include <linux/pci.h>

#define PCI_VIRTIOGPU_VENDOR_ID 0x1af4
#define PCI_VIRTIOGPU_DEVICE_ID 0x1050

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Ananta Srikar");
MODULE_DESCRIPTION("Basic DRM driver for virtio-gpu-pci");

static struct pci_device_id pci_virtiogpu_ids[] = {
	{ PCI_DEVICE(PCI_VIRTIOGPU_VENDOR_ID, PCI_VIRTIOGPU_DEVICE_ID) },
	{ }
};

MODULE_DEVICE_TABLE(pci, pci_virtiogpu_ids);

static int pci_virtiogpu_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	pr_info("pci_virtiogpu: PCI probe function called!\n");
	return 0;
}

static void pci_virtiogpu_remove(struct pci_dev *pdev)
{
	pr_info("pci_virtiogpu: PCI remove function called!\n");
}

static struct pci_driver pci_virtiogpu_driver = {
	.name = "virtiogpu",
	.id_table = pci_virtiogpu_ids,
	.probe = pci_virtiogpu_probe,
	.remove = pci_virtiogpu_remove,
};

static int __init virtiogpu_init(void)
{
	pr_info("pci_virtiogpu: Kernel module init called!\n");
	return pci_register_driver(&pci_virtiogpu_driver);
}

static void __exit virtiogpu_exit(void)
{
	pr_info("pci_virtiogpu: Kernel module exit called!\n");
	pci_unregister_driver(&pci_virtiogpu_driver);
}

module_init(virtiogpu_init);
module_exit(virtiogpu_exit);