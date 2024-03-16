import java.util.Scanner;

public class Szamologep {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        while (true) {
            System.out.print("Adj meg egy számot: ");
            double num1 = scanner.nextDouble();
            System.out.print("Adj meg egy számot: ");
            double num2 = scanner.nextDouble();

            System.out.println("Válassz műveletet:");
            System.out.println("1. Összeadás");
            System.out.println("2. Kivonás");
            System.out.println("3. Szorzás");
            System.out.println("4. Osztás");
            System.out.println("5. Kilépés");

            int choice = scanner.nextInt();

            switch (choice) {
                case 1:
                    System.out.println("Eredmény: " + (num1 + num2));
                    break;
                case 2:
                    System.out.println("Eredmény: " + (num1 - num2));
                    break;
                case 3:
                    System.out.println("Eredmény: " + (num1 * num2));
                    break;
                case 4:
                    if (num2 != 0) {
                        System.out.println("Eredmény: " + (num1 / num2));
                    } else {
                        System.out.println("Nullával nem oszthatunk!");
                    }
                    break;
                case 5:
                    System.out.println("Kilépés.");
                    return;
                default:
                    System.out.println("Hiba!");
            }
        }
    }
}